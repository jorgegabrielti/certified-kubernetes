# Instalação e Configuração de Cluster Kubernetes com kubeadm

> Baseado na documentação oficial:
> - [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
> - [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
> - [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)

---

## Visão Geral

Este tutorial cobre a instalação de um cluster Kubernetes de 1 control-plane + N workers usando `kubeadm` no Ubuntu 22.04 (Jammy). O ambiente usado como referência é o provisionado pelo Terraform neste repositório (instâncias EC2 t3.medium na AWS), mas os passos são válidos para qualquer máquina Linux com Ubuntu 22.04.

**Topologia:**
```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│      master         │     │      worker01        │     │      worker02        │
│  (control-plane)    │     │      (worker)        │     │      (worker)        │
│  10.0.1.x           │     │  10.0.1.x            │     │  10.0.1.x            │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

---

## Pré-requisitos

Execute os itens abaixo em **todos os nós** (master + workers) antes de iniciar.

### Requisitos da máquina

| Componente | Mínimo | Recomendado (lab) |
|---|---|---|
| RAM | 2 GB | 4 GB (t3.medium = 4 GB) |
| CPUs | 2 (control-plane) / 1 (worker) | 2 |
| Disco | 10 GB | 30 GB |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| Rede | Conectividade plena entre nós | VPC privada |

### Conectar nas instâncias

```bash
# Master
ssh -i ~/.ssh/cka-keypair.pem ubuntu@<master_public_ip>

# Worker01
ssh -i ~/.ssh/cka-keypair.pem ubuntu@<worker01_public_ip>

# Worker02
ssh -i ~/.ssh/cka-keypair.pem ubuntu@<worker02_public_ip>
```

> Obtenha os IPs com: `terraform output` no diretório `IAC/terraform/aws/`

---

## Parte 1 — Preparação do Sistema (todos os nós)

Execute todos os comandos desta seção em **cada máquina** (master e workers).

### 1.1 Desabilitar swap

O kubeadm exige swap desabilitado. Caso contrário, o preflight check falha com _"running with swap on is not supported"_.

```bash
sudo swapoff -a
sudo sed -i '/\bswap\b/d' /etc/fstab
```

Verifique:
```bash
free -h
# A linha "Swap:" deve mostrar 0B
```

### 1.2 Instalar pacotes base

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gpg \
  conntrack \
  socat \
  ipset \
  ipvsadm
```

> **Por que esses pacotes?**
> - `gpg` — decodifica a chave do repositório kubernetes (não `pgp`)
> - `conntrack` — rastreamento de conexões, exigido pelo kubeadm no preflight
> - `socat` — port-forwarding, usado pelo `kubectl port-forward`
> - `ipset` / `ipvsadm` — necessários para kube-proxy em modo IPVS

### 1.3 Carregar módulos do kernel

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

Verifique:
```bash
lsmod | grep -E "overlay|br_netfilter"
```

> - `overlay` — filesystem em camadas para imagens de container (OverlayFS)
> - `br_netfilter` — permite que iptables inspecione tráfego em bridges de rede

### 1.4 Configurar parâmetros do kernel (sysctl)

```bash
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
```

Verifique:
```bash
sysctl net.ipv4.ip_forward
# Esperado: net.ipv4.ip_forward = 1
```

> Sem `ip_forward`, o nó não encaminha pacotes entre pods de nós diferentes.

---

## Parte 2 — Instalação do containerd (todos os nós)

### 2.1 Instalar containerd

```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y containerd
```

### 2.2 Configurar cgroup driver

O kubelet no Ubuntu 22.04 usa `systemd` como cgroup driver. O containerd por padrão usa `cgroupfs`. Essa divergência causa `CrashLoopBackOff` em todos os pods do sistema.

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Ativar SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

Verifique a mudança:
```bash
grep SystemdCgroup /etc/containerd/config.toml
# Esperado: SystemdCgroup = true
```

### 2.3 Iniciar e habilitar containerd

```bash
sudo systemctl enable --now containerd
sudo systemctl status containerd
```

---

## Parte 3 — Instalação do Kubernetes (todos os nós)

### 3.1 Adicionar repositório oficial

```bash
# Defina a versão desejada (track minor, ex: v1.31)
K8S_VERSION="v1.31"

sudo mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### 3.2 Instalar kubelet, kubeadm e kubectl

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl

# Impede upgrade automático (evita version skew acidental)
sudo apt-mark hold kubelet kubeadm kubectl
```

Verifique:
```bash
kubeadm version
kubectl version --client
kubelet --version
```

### 3.3 Configurar node-ip do kubelet

Em ambientes cloud (AWS, GCP, etc.) a instância pode ter múltiplas interfaces. Configure o kubelet para anunciar o IP privado correto:

```bash
# Obtenha o IP privado via IMDSv2 (AWS)
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

echo "IP privado: ${PRIVATE_IP}"

# Configurar no kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=${PRIVATE_IP}" | sudo tee /etc/default/kubelet
sudo systemctl enable kubelet
```

---

## Parte 4 — Inicializar o Control Plane (somente master)

### 4.1 Executar kubeadm init

```bash
# Obtenha o IP privado (se não tiver feito ainda)
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

sudo kubeadm init \
  --apiserver-advertise-address="${PRIVATE_IP}" \
  --pod-network-cidr="10.244.0.0/16"
```

> **Flags importantes:**
> - `--apiserver-advertise-address` — IP que o API Server anuncia. Deve ser o IP privado para comunicação intra-VPC.
> - `--pod-network-cidr` — CIDR da rede de pods. Deve ser diferente do CIDR da VPC e do CIDR de serviços (`10.96.0.0/12`). O valor `10.244.0.0/16` é compatível com Flannel e Cilium.
> - Em instâncias com 1 vCPU (lab), adicione `--ignore-preflight-errors=NumCPU`

**Saída esperada ao final:**
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You can now join any number of machines by running the following on each node as root:

  kubeadm join <control-plane-ip>:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

> **IMPORTANTE:** Copie e salve o comando `kubeadm join` — você vai precisar dele na Parte 6.

### 4.2 Configurar kubectl para o usuário ubuntu

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4.3 Verificar o control plane

```bash
kubectl get nodes
# Esperado: master com status NotReady (CNI ainda não instalado)

kubectl get pods -n kube-system
# coredns ficará em Pending até o CNI ser instalado — isso é normal
```

---

## Parte 5 — Instalar CNI (somente master)

O cluster não funciona sem um plugin CNI (Container Network Interface). O CoreDNS ficará em `Pending` até esta etapa.

### Opção A — Flannel (simples, recomendado para lab)

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### Opção B — Cilium (eBPF, recomendado para estudo de networking avançado)

> Baseado na [documentação oficial do Cilium](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/).

**1. Instalar o Cilium CLI:**

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

**2. Instalar o Cilium no cluster:**

```bash
cilium install --version 1.16.6
```

> O installer detecta automaticamente a melhor configuração para o cluster. Não passe flags `--helm-set` adicionais — elas podem impedir a criação do DaemonSet.

**3. Validar a instalação:**

```bash
cilium status --wait
```

Saída esperada:
```
   /¯¯\
/¯¯\__/¯¯\    Cilium:         OK
\__/¯¯\__/    Operator:       OK
/¯¯\__/¯¯\    Hubble:         disabled
\__/¯¯\__/    ClusterMesh:    disabled
   \__/

DaemonSet    cilium           Desired: 1, Ready: 1/1, Available: 1/1
Deployment   cilium-operator  Desired: 1, Ready: 1/1, Available: 1/1
```

**4. (Opcional) Teste de conectividade:**

```bash
cilium connectivity test
```

### Verificar CNI

```bash
kubectl get pods -n kube-system
# Todos os pods devem estar Running

kubectl get nodes
# master deve agora estar Ready
```

---

## Parte 6 — Adicionar Workers ao Cluster

### 6.1 Obter o join command no master

```bash
# Se perdeu o comando gerado pelo kubeadm init, gere um novo token:
kubeadm token create --print-join-command
```

### 6.2 Executar em cada worker

**Em cada worker** (como root):

```bash
sudo kubeadm join <control-plane-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

> Substitua `<control-plane-ip>`, `<token>` e `<hash>` pelos valores do passo anterior.

### 6.3 Verificar no master

```bash
kubectl get nodes -o wide
```

**Saída esperada:**
```
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP   ...
master     Ready    control-plane   10m   v1.31.x   10.0.1.10
worker01   Ready    <none>          2m    v1.31.x   10.0.1.11
worker02   Ready    <none>          2m    v1.31.x   10.0.1.12
```

---

## Parte 7 — Verificação Final

```bash
# Todos os nós prontos
kubectl get nodes

# Todos os pods do sistema em Running
kubectl get pods -A

# Informações do cluster
kubectl cluster-info

# Deploy de teste
kubectl create deployment nginx --image=nginx --replicas=3
kubectl get pods -o wide

# Verificar distribuição entre workers
# Os pods devem aparecer em diferentes nós

# Limpar o teste
kubectl delete deployment nginx
```

---

## Parte 8 — Desfazer (limpeza)

### Remover um worker do cluster

No master:
```bash
kubectl drain <worker-node-name> --delete-emptydir-data --force --ignore-daemonsets
kubectl delete node <worker-node-name>
```

No worker:
```bash
sudo kubeadm reset
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

### Resetar o control plane

```bash
sudo kubeadm reset
sudo rm -rf /etc/kubernetes /var/lib/etcd $HOME/.kube
```

---

## Troubleshooting

### kubectl: `dial tcp 127.0.0.1:8080: connection refused`

**Causa:** `KUBECONFIG` não configurado para o usuário atual.

```bash
# Usuário ubuntu (SSH padrão) — deve funcionar diretamente após o kubeadm init
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Ou, como root (temporário):
export KUBECONFIG=/etc/kubernetes/admin.conf
```

---

### `coredns` em estado `Pending`

**Causa:** CNI não instalado. É comportamento esperado — instale o CNI (Parte 5).

```bash
kubectl get pods -n kube-system
# coredns ficará Pending até o CNI ser aplicado
```

---

### Pods em `CrashLoopBackOff` logo após o init

**Causa mais comum:** conflito de cgroup driver entre containerd e kubelet.

```bash
# Verifique se SystemdCgroup está true
grep SystemdCgroup /etc/containerd/config.toml

# Se estiver false, corrija e reinicie
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

---

### `[ERROR FileExisting-conntrack]` no preflight

**Causa:** pacote `conntrack` não instalado.

```bash
sudo apt-get install -y conntrack
```

---

### `kubeadm init` trava em `[apiclient] Created API client, waiting for the control plane to become ready`

Possíveis causas:
1. **Problema de rede** — verifique conectividade entre os nós
2. **cgroup driver mismatch** — veja o item acima
3. **Container crashando** — inspecione com crictl:

```bash
sudo crictl ps -a
sudo crictl logs <container-id>
```

---

### Certificado TLS inválido (`x509: certificate signed by unknown authority`)

**Causa:** O `kubeadm init` foi executado mais de uma vez (ex: após um `kubeadm reset`), gerando novos certificados. O `~/.kube/config` ainda contém os certificados antigos.

```bash
# Reconfigurar kubeconfig com os certificados atuais
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

Para confirmar que os certs batem:
```bash
# Cert que o API Server está servindo
echo | openssl s_client -connect 10.0.1.26:6443 2>/dev/null | openssl x509 -noout -issuer -dates

# CA no kubeconfig
grep certificate-authority-data ~/.kube/config | awk '{print $2}' | base64 -d | openssl x509 -noout -issuer -dates
```

> **Regra:** Sempre re-copie o `admin.conf` após cada `kubeadm init`.

---

### Cilium instalado mas DaemonSet não criado (`daemonsets.apps "cilium" not found`)

**Causa:** O `cilium install` foi executado com flags incompatíveis (ex: `--helm-set kubeProxyReplacement`, `--helm-set k8sServiceHost`) que conflitam com a versão instalada ou com a configuração do cluster, fazendo o install falhar silenciosamente.

```bash
# Verificar se há pods do Cilium
kubectl get pods -n kube-system | grep cilium

# Desinstalar e reinstalar sem flags extras
cilium uninstall --wait
cilium install
cilium status --wait
```
```

---

### Token expirado ao tentar join (tokens expiram em 24h por padrão)

```bash
# No master, gere um novo token
kubeadm token create --print-join-command
```

---

### Worker fica em `NotReady` após join

```bash
# No master, verifique os eventos do nó
kubectl describe node <worker-name>

# No worker, verifique o kubelet
sudo journalctl -u kubelet -f

# Causa comum: kubelet anunciando IP errado
# Verifique /etc/default/kubelet no worker
cat /etc/default/kubelet
# Deve conter: KUBELET_EXTRA_ARGS=--node-ip=<private-ip>
```

---

## Referências

- [Installing kubeadm — kubernetes.io](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Creating a cluster with kubeadm — kubernetes.io](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Troubleshooting kubeadm — kubernetes.io](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)
- [Container Runtimes — kubernetes.io](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Configuring a cgroup driver — kubernetes.io](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/)
