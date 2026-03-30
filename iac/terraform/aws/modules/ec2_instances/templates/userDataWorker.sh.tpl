#!/bin/bash
# =============================================================================
# Cluster Kubernetes — Bootstrap do Worker Node
# =============================================================================
# Role:    worker
# K8s:     ${k8s_version}
# Author:  Jorge Gabriel (Site Reliability Engineer)
#
# VISÃO GERAL
# -----------
# Este script é executado uma única vez pelo cloud-init na primeira inicialização
# da instância EC2. Ele instala e configura todos os pré-requisitos do Kubernetes
# no nó worker, mas NÃO executa o kubeadm join automaticamente — isso requer o
# token gerado pelo master, que só fica disponível após o bootstrap do master.
#
#   [1/6] Desabilita swap              — requisito obrigatório do kubeadm
#   [2/6] Instala pacotes base         — dependências do containerd e do kubeadm
#   [3/6] Carrega módulos do kernel    — overlay e br_netfilter para networking
#   [4/6] Instala e configura containerd — CRI com SystemdCgroup habilitado
#   [5/6] Instala kubelet/kubeadm/kubectl — pacotes oficiais do k8s.io
#   [6/6] Configura kubelet node-ip    — via IMDSv2 para comunicação intra-VPC
#
# COMO INGRESSAR NO CLUSTER APÓS O BOOTSTRAP
# ------------------------------------------
# 1. Aguarde o master terminar:
#      ssh -i ~/.ssh/cka-keypair.pem ubuntu@<master_public_ip> \
#        "tail -f /var/log/k8s-master-init.log"
#    Aguarde: "=== Master provisioning complete ==="
#
# 2. Obtenha o join command no master:
#      ssh -i ~/.ssh/cka-keypair.pem ubuntu@<master_public_ip> \
#        "sudo cat /root/kubeadm-join.sh"
#
# 3. Execute em cada worker como root:
#      ssh -i ~/.ssh/cka-keypair.pem ubuntu@<worker_public_ip> \
#        "sudo <join_command>"
#
# VARIÁVEIS DO TERRAFORM (interpoladas em tempo de apply)
# -------------------------------------------------------
#   ${k8s_version} — ex: "v1.30" (track do repositório pkgs.k8s.io)
#
# NOTA SOBRE ESCAPE $${}
# ----------------------
# Variáveis Bash dentro deste template usam $${VAR} (dois cifrões) para que o
# Terraform não as interprete como suas próprias interpolações. No script
# gerado, $${VAR} se torna ${VAR} normalmente.
#
# OBSERVAR O PROGRESSO
# --------------------
#   tail -f /var/log/k8s-worker-init.log
# =============================================================================

# Aborta imediatamente em caso de erro, variável não definida ou falha em pipe.
set -euo pipefail

# Duplica stdout/stderr para o arquivo de log e para o systemd journal.
exec > >(tee /var/log/k8s-worker-init.log | logger -t k8s-worker-init) 2>&1
echo "=== [1/6] Starting worker provisioning ==="

# ─── Swap ─────────────────────────────────────────────────────────────────────
# O kubeadm exige swap desabilitado. Caso contrário, o preflight check falha
# com "running with swap on is not supported". O sed remove a entrada do fstab
# para garantir que swap não seja reativado após um reboot.
swapoff -a
sed -i '/\bswap\b/d' /etc/fstab

# ─── Base packages ────────────────────────────────────────────────────────────
echo "=== [2/6] Installing base packages ==="
apt-get update -qq

# DEBIAN_FRONTEND=noninteractive evita prompts interativos do apt (ex: tzdata)
# que travam cloud-init indefinidamente sem TTY disponível.
#
# Pacotes necessários:
#   apt-transport-https — HTTPS para repositórios apt
#   ca-certificates     — validação de TLS dos repositórios
#   curl                — download de chaves GPG e binários
#   gpg                 — decodificação de chaves de repositório (NÃO 'pgp')
#   conntrack           — rastreamento de conexões; exigido pelo kubeadm preflight
#   socat               — port-forwarding; usado pelo kubectl port-forward
#   ipset               — conjuntos de IPs para regras de firewall
#   ipvsadm             — gerenciamento do IPVS (kube-proxy em modo IPVS)
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apt-transport-https ca-certificates curl gpg \
  conntrack socat ipset ipvsadm

# ─── Kernel modules ───────────────────────────────────────────────────────────
echo "=== [3/6] Loading kernel modules ==="

# overlay   — filesystem em camadas para imagens de container (OverlayFS)
# br_netfilter — permite que regras iptables inspecionem tráfego em bridges,
#               necessário para que o kube-proxy e Cilium funcionem corretamente.
#
# O arquivo modules-load.d garante que os módulos sejam carregados
# automaticamente após um reboot.
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# ─── Sysctl ───────────────────────────────────────────────────────────────────
# Parâmetros do kernel obrigatórios para o funcionamento do Kubernetes:
#   ip_forward                — permite que o nó encaminhe pacotes entre interfaces
#   bridge-nf-call-iptables   — faz bridges passarem pelo iptables (IPv4)
#   bridge-nf-call-ip6tables  — idem para IPv6
#
# Sem esses parâmetros, tráfego entre pods em nós diferentes é descartado.
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# ─── containerd ───────────────────────────────────────────────────────────────
echo "=== [4/6] Installing containerd ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y containerd

# Gera a configuração padrão e ativa o SystemdCgroup.
# Por padrão, containerd usa cgroupfs, mas o kubelet no Ubuntu 22.04 usa
# systemd como cgroup driver. Divergência de drivers causa CrashLoopBackOff
# em todos os pods do sistema. O sed usa match exato para não alterar outras
# ocorrências de 'SystemdCgroup' que possam existir em runtimes adicionais.
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd

# ─── Kubernetes packages ──────────────────────────────────────────────────────
echo "=== [5/6] Installing Kubernetes ${k8s_version} ==="

# Adiciona o repositório oficial pkgs.k8s.io para o track ${k8s_version}.
# A versão instalada no worker DEVE ser compatível com a do master (mesmo track).
# 'apt-mark hold' impede upgrade automático que causaria skew de versão.
mkdir -p /etc/apt/keyrings
K8S_TRACK="${k8s_version}"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$${K8S_TRACK}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${K8S_TRACK}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ─── Private IP via IMDSv2 ────────────────────────────────────────────────────
echo "=== [6/6] Configuring kubelet node-ip ==="

# Obtém o IP privado via IMDSv2 (Instance Metadata Service v2).
# IMDSv2 usa um token de sessão para prevenir SSRF — a AWS desabilita IMDSv1
# por padrão em instâncias novas. O IP privado é usado como node-ip para que
# o kubelet anuncie o endereço correto ao API Server do master.
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $${IMDS_TOKEN}" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

# Força o kubelet a anunciar o IP privado.
# Sem isso, em ambientes multi-interface, o kubelet pode anunciar um IP
# inalcançável pelo master (ex: IP público do ENI primário).
echo "KUBELET_EXTRA_ARGS=--node-ip=$${PRIVATE_IP}" > /etc/default/kubelet
systemctl restart kubelet

echo "=== Worker provisioning complete ==="
echo "=== Join this node to the cluster: ==="
echo "===   1. ssh ubuntu@<master_public_ip> ==="
echo "===   2. sudo cat /root/kubeadm-join.sh ==="
echo "===   3. Run the printed command on this node as root ==="

# ─── Swap ─────────────────────────────────────────────────────────────────────
grep -q swap /etc/fstab && swapoff -a && sed -i '/swap/d' /etc/fstab || true

# ─── Base packages ────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y apt-transport-https ca-certificates curl pgp \
  conntrack socat ipset ipvsadm

# ─── Kernel modules ───────────────────────────────────────────────────────────
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ─── Sysctl ───────────────────────────────────────────────────────────────────
cat <<EOF | tee /etc/sysctl.d/99-kubernetes.conf
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.forwarding        = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.rp_filter         = 0
EOF

sysctl --system

# ─── containerd ───────────────────────────────────────────────────────────────
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup.*/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl enable --now containerd

# ─── Kubernetes ${k8s_version} ─────────────────────────────────────────────────────────
K8S_TRACK="${k8s_version}"

curl -fsSL "https://pkgs.k8s.io/core:/stable:/$${K8S_TRACK}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${K8S_TRACK}/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# ─── Get private IP via IMDSv2 ────────────────────────────────────────────────
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

echo "KUBELET_EXTRA_ARGS=--node-ip=$${PRIVATE_IP}" | tee /etc/default/kubelet
systemctl daemon-reexec
systemctl enable --now kubelet

echo "=== Worker provisioning complete ==="
echo "=== To join the cluster, run as root: ==="
echo "===   1. ssh ubuntu@<master_public_ip> ==="
echo "===   2. sudo cat /root/kubeadm-join.sh ==="
echo "===   3. Run the join command on this node ==="
