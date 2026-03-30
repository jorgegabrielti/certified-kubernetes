#!/bin/bash
# =============================================================================
# Cluster Kubernetes — Bootstrap do Control Plane (master)
# =============================================================================
# Role:    control-plane (master)
# K8s:     ${k8s_version}
# Author:  Jorge Gabriel (Site Reliability Engineer)
#
# VISÃO GERAL
# -----------
# Este script é executado uma única vez pelo cloud-init na primeira inicialização
# da instância EC2. Ele realiza as 8 etapas a seguir em ordem:
#
#   [1/8] Desabilita swap              — requisito obrigatório do kubeadm
#   [2/8] Instala pacotes base         — dependências do containerd e do kubeadm
#   [3/8] Carrega módulos do kernel    — overlay e br_netfilter para networking
#   [4/8] Instala e configura containerd — CRI com SystemdCgroup habilitado
#   [5/8] Instala kubelet/kubeadm/kubectl — pacotes oficiais do k8s.io
#   [6/8] Inicializa o cluster          — kubeadm init com IP privado
#   [7/8] Instala o CNI Cilium          — sem kube-proxy, modo eBPF
#   [8/8] Salva o join command          — em /root/kubeadm-join.sh para os workers
#
# VARIÁVEIS DO TERRAFORM (interpoladas em tempo de apply)
# -------------------------------------------------------
#   ${k8s_version}      — ex: "v1.30"  (track do repositório pkgs.k8s.io)
#   ${pod_network_cidr} — ex: "10.244.0.0/16" (CIDR da rede de pods)
#
# NOTA SOBRE ESCAPE $${}
# ----------------------
# Variáveis Bash dentro deste template usam $${VAR} (dois cifrões) para que o
# Terraform não as interprete como suas próprias interpolações. No script
# gerado, $${VAR} se torna ${VAR} normalmente.
#
# OBSERVAR O PROGRESSO
# --------------------
#   tail -f /var/log/k8s-master-init.log
# =============================================================================

# Aborta imediatamente em caso de erro, variável não definida ou falha em pipe.
# Garante que falhas silenciosas não deixem o cluster em estado parcial.
set -euo pipefail

# Duplica stdout/stderr para o arquivo de log e para o systemd journal.
# O tee gravará o log em disco enquanto logger envia para journald.
exec > >(tee /var/log/k8s-master-init.log | logger -t k8s-master-init) 2>&1
echo "=== [1/8] Starting master provisioning ==="

# ─── Swap ─────────────────────────────────────────────────────────────────────
# O kubeadm exige swap desabilitado. Caso contrário, o preflight check falha
# com "running with swap on is not supported". O sed remove a entrada do fstab
# para garantir que swap não seja reativado após um reboot.
swapoff -a
sed -i '/\bswap\b/d' /etc/fstab

# ─── Base packages ────────────────────────────────────────────────────────────
echo "=== [2/8] Installing base packages ==="
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
echo "=== [3/8] Loading kernel modules ==="

# overlay   — filesytem em camadas para imagens de container (OverlayFS)
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
echo "=== [4/8] Installing containerd ==="
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
echo "=== [5/8] Installing Kubernetes ${k8s_version} ==="

# Adiciona o repositório oficial pkgs.k8s.io para o track ${k8s_version}.
# Cada minor version do K8s tem seu próprio repositório (ex: v1.30, v1.31),
# o que permite atualizar o track sem mudar a URL base do apt.
mkdir -p /etc/apt/keyrings
K8S_TRACK="${k8s_version}"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$${K8S_TRACK}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$${K8S_TRACK}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl

# 'apt-mark hold' impede que apt atualize automaticamente os componentes K8s,
# evitando upgrade acidental que resultaria em skew de versão entre nós.
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ─── Private IP via IMDSv2 ────────────────────────────────────────────────────
echo "=== [6/8] Running kubeadm init ==="

# Obtém o IP privado via IMDSv2 (Instance Metadata Service v2).
# IMDSv2 usa um token de sessão para prevenir SSRF; a AWS desabilita IMDSv1
# por padrão em instâncias novas. O IP privado é usado como endereço de
# anúncio do API Server para que os workers se conectem pela rede interna
# (sem custo de transferência de dados inter-região).
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $${IMDS_TOKEN}" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

# Força o kubelet a anunciar o IP privado como node-ip.
# Sem isso, o kubelet pode anunciar o IP da interface errada em ambientes
# com múltiplas interfaces (ex: eth0 pública, eth1 privada).
echo "KUBELET_EXTRA_ARGS=--node-ip=$${PRIVATE_IP}" > /etc/default/kubelet
systemctl restart kubelet

# ─── kubeadm init ─────────────────────────────────────────────────────────────
# --apiserver-advertise-address: IP que o API Server anuncia aos workers.
#   Deve ser o IP privado para comunicação intra-VPC.
# --pod-network-cidr: CIDR reservado para IPs de pods. Deve ser diferente
#   do CIDR da VPC (10.0.0.0/16) e do CIDR de serviços (padrão 10.96.0.0/12).
# --ignore-preflight-errors=NumCPU: instâncias t2/t3.micro têm 1 vCPU, abaixo
#   do mínimo recomendado (2). Ignorado pois o objetivo é estudo/lab, não prod.
kubeadm init \
  --apiserver-advertise-address="$${PRIVATE_IP}" \
  --pod-network-cidr="${pod_network_cidr}" \
  --ignore-preflight-errors=NumCPU

# ─── kubectl para o usuário ubuntu ────────────────────────────────────────────
# Copia o admin.conf para o home do usuário ubuntu, permitindo usar kubectl
# via SSH sem sudo. O KUBECONFIG para root é exportado na sessão atual para
# as etapas seguintes (cilium install, kubeadm token create) que rodam como root.
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

# Aguarda o API Server aceitar conexões antes de prosseguir.
# Após o kubeadm init, o API Server pode levar alguns segundos para
# responder enquanto os certificados são carregados.
until kubectl get nodes &>/dev/null; do
  echo "Waiting for API server..."
  sleep 5
done
echo "API server ready."

# ─── CNI: Cilium ──────────────────────────────────────────────────────────────
echo "=== [7/8] Installing Cilium CNI ==="

# Baixa a versão mais recente estável do Cilium CLI.
# A arquitetura é detectada automaticamente (amd64 para x86_64, arm64 para
# instâncias Graviton). O sha256sum valida a integridade do binário.
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
[ "$(uname -m)" = "aarch64" ] && CLI_ARCH=arm64

cd /tmp
curl -fsSL --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/$${CILIUM_CLI_VERSION}/cilium-linux-$${CLI_ARCH}.tar.gz" \
  "https://github.com/cilium/cilium-cli/releases/download/$${CILIUM_CLI_VERSION}/cilium-linux-$${CLI_ARCH}.tar.gz.sha256sum"
sha256sum --check "cilium-linux-$${CLI_ARCH}.tar.gz.sha256sum"
tar -xzf "cilium-linux-$${CLI_ARCH}.tar.gz" -C /usr/local/bin
rm "cilium-linux-$${CLI_ARCH}.tar.gz" "cilium-linux-$${CLI_ARCH}.tar.gz.sha256sum"

# Instala o Cilium como operador Helm via CLI.
# IMPORTANTE: deve rodar como root com KUBECONFIG exportado.
#   sudo -u ubuntu cilium install falharia pois o usuário ubuntu não tem
#   acesso ao admin.conf durante cloud-init (antes do chown acima).
#
# --helm-set kubeProxyReplacement=false: modo compatível; mantém o kube-proxy
#   instalado pelo kubeadm. Útil em labs para evitar dependências de eBPF.
# --helm-set k8sServiceHost/Port: endereço do API Server para o Cilium Agent
#   acessar o cluster sem depender do DNS do CoreDNS (que ainda não está up).
cilium install \
  --helm-set kubeProxyReplacement=false \
  --helm-set k8sServiceHost="$${PRIVATE_IP}" \
  --helm-set k8sServicePort=6443

# Aguarda todos os pods do Cilium ficarem Running antes de salvar o join command.
# O '|| true' evita que a falha do wait aborte o script — em caso de timeout,
# o cluster ainda pode funcionar; o status pode ser verificado manualmente.
echo "Waiting for Cilium to be ready..."
cilium status --wait || true

# ─── Save join command ────────────────────────────────────────────────────────
echo "=== [8/8] Saving join command ==="

# Gera um novo bootstrap token e salva o comando de join completo em arquivo.
# O arquivo /root/kubeadm-join.sh é lido pelos workers via:
#   ssh ubuntu@<master_ip> sudo cat /root/kubeadm-join.sh
#
# Permissão 600: apenas root pode ler (o token permite ingressar no cluster).
# printf em vez de echo evita interpretação de caracteres especiais no token.
JOIN_CMD=$(kubeadm token create --print-join-command)
printf '#!/bin/bash\n%s\n' "$${JOIN_CMD}" > /root/kubeadm-join.sh
chmod 600 /root/kubeadm-join.sh

echo "=== Join command: $${JOIN_CMD} ==="
echo "=== Master provisioning complete ==="
