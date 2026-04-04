# Construindo um Cluster Kubernetes do Zero com kubeadm

> **Série:** Kubernetes Descomplicado — Guia Prático para a CKA  
> **Domínio:** Cluster Architecture, Installation and Configuration (25% do exame)  
> **Cobre:** Sub-tópicos 01 (Infrastructure Provisioning) e 02 (Kubeadm Install)

---

## Por que este artigo existe?

Existe uma quantidade enorme de tutoriais que mostram como subir um cluster Kubernetes. A maioria deles funciona — até funcionar errado.

O problema não são os comandos. É a falta de explicação de **por que** cada passo existe. Quando algo quebra (e vai quebrar), você fica olhando para um erro sem entender o que causou.

Este guia percorre os dois primeiros sub-tópicos do domínio mais pesado da CKA: provisionar a infraestrutura base e inicializar o cluster com `kubeadm`. Cada passo vem acompanhado do motivo técnico por trás dele.

---

## O Ambiente Local

O cluster é composto por duas máquinas virtuais rodando sobre VirtualBox no host local. Cada VM tem duas interfaces de rede: uma interface NAT gerenciada pelo hypervisor (usada para acesso externo à internet) e uma interface Host-Only com IP fixo, que forma a rede privada de comunicação entre os nodes.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Host (sua máquina)                                                          │
│                                                                              │
│  Acessos expostos:  localhost:1020 ──► master01:443  (kube-apiserver)       │
│                     localhost:1021 ──► worker01:8443                        │
│                                                                              │
│  ┌─────────────────────── Host-Only · vboxnet0 · 192.168.56.0/24 ────────┐  │
│  │                                                                        │  │
│  │   ┌───────────────────────────┐      ┌───────────────────────────┐   │  │
│  │   │  master01                 │      │  worker01                 │   │  │
│  │   │  Ubuntu 22.04 LTS         │      │  Ubuntu 22.04 LTS         │   │  │
│  │   │  2 vCPU · 2 GB · 30 GB   │      │  2 vCPU · 2 GB · 30 GB   │   │  │
│  │   │                           │      │                           │   │  │
│  │   │  eth0 (NAT)  10.0.2.15   │      │  eth0 (NAT)  10.0.2.15   │   │  │
│  │   │  eth1        192.168.56.10│      │  eth1        192.168.56.11│   │  │
│  │   │                           │      │                           │   │  │
│  │   │  ── Control Plane ──      │      │  ── Worker ──             │   │  │
│  │   │  kube-apiserver           │      │  kubelet                  │   │  │
│  │   │  etcd                     │      │  containerd               │   │  │
│  │   │  kube-scheduler           │      │  kube-proxy / CNI agent   │   │  │
│  │   │  controller-manager       │      │                           │   │  │
│  │   │  kubelet + containerd     │      │                           │   │  │
│  │   └───────────────────────────┘      └───────────────────────────┘   │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  Rede de Pods (overlay — gerenciada pelo CNI):  10.244.0.0/16               │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Por que duas interfaces por node?**

A interface NAT (`eth0`) é criada automaticamente pelo VirtualBox para que a VM acesse a internet — necessária para baixar pacotes. O problema é que todos os nodes compartilham o mesmo IP nessa interface (`10.0.2.15`), o que inviabiliza a comunicação entre eles via esse caminho.

A interface Host-Only (`eth1`) cria uma rede privada isolada entre o host e as VMs, com IPs fixos e únicos por node. É por essa interface que o Kubernetes se comunica: o `kubeadm init` é executado com `--apiserver-advertise-address=192.168.56.10`, e o kubelet é configurado com `--node-ip` apontando para o IP da `eth1`. Sem essa separação, o cluster falha na inicialização porque os componentes tentam se comunicar pelo IP de NAT, que não é roteável entre os nodes.

---

## A Regra de Ouro

> **Tudo na Parte 1 (infraestrutura) deve ser executado em TODOS os nodes — master e workers.**

Não existe pré-requisito exclusivo do control plane nessa etapa. Cada node que entra no cluster precisa passar pelos mesmos passos.

---

## Parte 1 — Preparando a Infraestrutura

### 1.1 O que o Kubernetes exige do Sistema Operacional

Antes de qualquer pacote Kubernetes, o SO precisa estar configurado para quatro requisitos:

| Requisito | Motivo |
|---|---|
| Swap **desabilitado** | O kubelet não suporta swap. Com ele ativo, o scheduling de pods se torna imprevisível |
| Módulo `br_netfilter` | Permite que iptables inspecione tráfego de bridges — sem isso, kube-proxy e CNIs não funcionam corretamente |
| `net.ipv4.ip_forward = 1` | Habilita roteamento IP entre interfaces. Sem isso, pods em nodes diferentes não se comunicam |
| Módulo `overlay` | Driver de storage do containerd (OverlayFS) |

Nenhum desses requisitos é frescura: cada um resolve um problema real de comunicação ou compatibilidade entre o kernel Linux e os componentes do Kubernetes.

### 1.2 Carregando os Módulos de Kernel

```bash
# Carregar imediatamente
sudo modprobe overlay
sudo modprobe br_netfilter

# Persistir após reboot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

Um detalhe que muita gente esquece: `modprobe` carrega o módulo apenas para a sessão atual. Sem o arquivo em `/etc/modules-load.d/`, o módulo some após o próximo reboot — e o node para de funcionar silenciosamente.

### 1.3 Parâmetros sysctl

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

O `sysctl --system` aplica todos os arquivos em `/etc/sysctl.d/` imediatamente, sem precisar reiniciar.

### 1.4 Desabilitando o Swap

```bash
# Desabilitar imediatamente
sudo swapoff -a

# Remover do fstab para não voltar no próximo boot
sudo sed -i '/\sswap\s/s/^/#/' /etc/fstab
```

> **Dica de prova CKA:** Antes de rodar `kubeadm init`, sempre confirme com `swapon --show`. Output vazio = pode prosseguir.

---

### 1.5 Instalando o Container Runtime: containerd

O Kubernetes não gerencia containers diretamente — ele delega ao **Container Runtime Interface (CRI)**. O `containerd` é o runtime padrão.

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

#### A configuração que mais derruba: SystemdCgroup

```bash
# Gerar arquivo de configuração padrão
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Ativar SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Reiniciar e habilitar
sudo systemctl restart containerd
sudo systemctl enable containerd
```

**Por que `SystemdCgroup = true` é crítico?**

O kubelet usa o systemd para gerenciar os cgroups dos pods — o mecanismo do Linux que controla CPU e memória de processos. Se o containerd usar o driver padrão (`cgroupfs`), os dois ficam em conflito. O resultado é um node que nunca entra em estado `Ready`, com erros como:

```
failed to run Kubelet: misconfiguration: kubelet cgroup driver: "systemd" 
is different from docker cgroup driver: "cgroupfs"
```

Depois de instalar, verifique o socket CRI:

```bash
ls -la /run/containerd/containerd.sock
```

Esse arquivo é o canal de comunicação entre o kubelet e o containerd. Sem ele, o kubelet não consegue iniciar.

---

### 1.6 Instalando kubeadm, kubelet e kubectl

#### O repositório APT por minor version

O Kubernetes mantém repositórios APT separados para cada minor version. Para instalar `v1.32.x`, aponte para o repositório `v1.32`:

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /
EOF

sudo apt-get update
```

#### Instalando e fixando a versão

```bash
sudo apt-get install -y kubeadm=1.32.0-1.1 kubelet=1.32.0-1.1 kubectl=1.32.0-1.1

# Impede upgrades acidentais
sudo apt-mark hold kubeadm kubelet kubectl
```

O `apt-mark hold` é fundamental. Um upgrade do `kubelet` sem coordenação com o control plane pode derrubar o node. Em Kubernetes, upgrades são processos deliberados — não algo que acontece em um `apt upgrade` desatento.

#### Configurando o Node IP (ambientes com múltiplas interfaces)

Se você usa Vagrant, AWS ou qualquer ambiente com múltiplas interfaces de rede, este passo é obrigatório:

```bash
echo "KUBELET_EXTRA_ARGS=--node-ip=<IP_DA_REDE_INTERNA>" | sudo tee /etc/default/kubelet

sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
```

Sem isso, o kubelet pode se anunciar com o IP de NAT (geralmente `10.0.2.15` no Vagrant). O `kubeadm init` falha com `context deadline exceeded` porque os componentes tentam se comunicar pelo IP errado.

> **É normal:** o kubelet fica em crash-loop até `kubeadm init` ser executado. Ele precisa das instruções do kubeadm para funcionar.

---

### 1.7 Configuração de Rede do Host

Em ambientes de lab, garanta resolução de nomes entre os nodes:

```bash
cat <<EOF | sudo tee -a /etc/hosts
192.168.56.10  master01
192.168.56.11  worker01
192.168.56.12  worker02
EOF
```

### 1.8 Checklist de Validação

Execute antes de inicializar o cluster:

```bash
echo "=== Swap (vazio = OK) ===" && swapon --show
echo "=== br_netfilter ===" && lsmod | grep br_netfilter
echo "=== ip_forward (deve ser 1) ===" && sysctl net.ipv4.ip_forward
echo "=== overlay ===" && lsmod | grep overlay
echo "=== containerd ===" && systemctl is-active containerd
echo "=== kubelet ===" && kubelet --version
echo "=== kubeadm ===" && kubeadm version -o short
echo "=== kubectl ===" && kubectl version --client -o yaml | grep gitVersion
```

Todos os checks passaram? Você está pronto para a Parte 2.

---

## Parte 2 — Inicializando o Cluster com kubeadm

### 2.1 O que é o kubeadm?

O `kubeadm` é a ferramenta oficial para **bootstrapping de clusters Kubernetes**. Diferente de distribuições como k3s ou minikube, o kubeadm produz um cluster "vanilla" — o mesmo tipo que você encontra em ambientes de produção e no exame CKA.

O `kubeadm init` automatiza:
- Geração de certificados TLS para todos os componentes
- Criação dos arquivos kubeconfig
- Geração dos static pod manifests (apiserver, etcd, controller-manager, scheduler)
- Configuração inicial de RBAC, CoreDNS e kube-proxy

### 2.2 O que acontece em cada fase do `kubeadm init`

| Fase | O que acontece |
|------|----------------|
| `preflight` | Valida pré-requisitos: swap, módulos, CRI, portas |
| `certs` | Gera a CA e certificados TLS em `/etc/kubernetes/pki/` |
| `kubeconfig` | Cria `admin.conf`, `kubelet.conf`, `controller-manager.conf`, `scheduler.conf` |
| `etcd` | Cria o static pod manifest do etcd |
| `control-plane` | Cria manifests do apiserver, controller-manager e scheduler |
| `kubelet-start` | Configura e inicia o kubelet no control plane |
| `upload-config` | Salva a configuração como ConfigMap no cluster |
| `mark-control-plane` | Adiciona taint `node-role.kubernetes.io/control-plane` ao node |
| `bootstrap-token` | Cria o token para join de workers |
| `addons` | Instala CoreDNS e kube-proxy |

---

### 2.3 Inicializando o Cluster

#### Forma simples (flags diretas)

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.56.10
```

#### Forma declarativa (preferida)

```yaml
# kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.32.0
controlPlaneEndpoint: "192.168.56.10:6443"
networking:
  podSubnet: "10.244.0.0/16"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "192.168.56.10"
  bindPort: 6443
```

```bash
sudo kubeadm init --config kubeadm-config.yaml
```

A forma declarativa é preferida porque o arquivo pode ser versionado, revisado e reutilizado. O kubeadm também salva essa configuração como um ConfigMap no cluster, útil para auditorias e upgrades posteriores.

#### CIDR de pods e escolha do CNI

O `--pod-network-cidr` define o range de IPs para pods. Cada CNI tem seu padrão:

| CNI | CIDR recomendado |
|-----|-----------------|
| Cilium | `10.244.0.0/16` |
| Calico | `192.168.0.0/16` |
| Flannel | `10.244.0.0/16` |

> **Dica de prova:** Se o exame não especificar o CNI, use o que você praticou. O importante é que o CIDR do `kubeadm init` bata com o que o CNI espera.

---

### 2.4 Configurando o kubeconfig

Após o `kubeadm init`, copie o kubeconfig para o usuário atual:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verificar acesso
kubectl get nodes
```

O master vai aparecer como `NotReady`. Isso é esperado — ele precisa do CNI para gerenciar a rede.

---

### 2.5 Instalando o CNI (Cilium)

```bash
# Instalar a Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar -xzvf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Instalar no cluster
cilium install \
  --set k8sServiceHost=192.168.56.10 \
  --set k8sServicePort=6443

# Aguardar todos os componentes ficarem prontos
cilium status --wait
```

Após a instalação do CNI, `kubectl get nodes` deve mostrar o master como `Ready`.

---

### 2.6 Adicionando Workers ao Cluster

O output do `kubeadm init` inclui o comando de join completo. Salve-o. Execute em cada worker:

```bash
sudo kubeadm join 192.168.56.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:<hash>
```

#### Token expirou?

Tokens de join expiram em **24 horas**. Para gerar um novo:

```bash
kubeadm token create --print-join-command
```

Esse comando imprime o join completo com token novo e hash atualizado — mais rápido do que reconstruir manualmente.

#### Verificando o cluster

```bash
# No master, após alguns segundos
kubectl get nodes -o wide
```

Todos os nodes devem aparecer como `Ready`.

---

### 2.7 Entendendo os Static Pod Manifests

Os componentes do control plane rodam como **static pods** — gerenciados diretamente pelo kubelet, sem passar pelo apiserver.

```bash
ls /etc/kubernetes/manifests/
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml
# etcd.yaml
```

Qualquer alteração nesses arquivos é detectada automaticamente pelo kubelet, que reinicia o pod correspondente. Isso tem uma implicação importante para troubleshooting: edite o YAML, aguarde ~30 segundos, e o componente volta. Mas se houver erro de sintaxe no YAML, o pod não sobe e o componente fica fora do ar.

> **Atenção:** Nunca use `kubectl delete pod` em static pods do control plane. Eles são recriados imediatamente pelo kubelet — o pod volta, mas o processo de término e recriação pode causar instabilidade temporária.

---

## Dicas do Instrutor (Transcrição da Aula Ao Vivo)

Estas dicas foram extraídas de uma aula ao vivo com instrutor que já realizou a prova CKA 3 vezes:

> **"Não precisa decorar as flags de kernel, configuração de swap, módulos — tudo isso já chega pré-configurado na prova. O que você precisa saber de cabeça são os dois comandos: `kubeadm init` e `kubeadm join`."**

| O que cai na prova | O que NÃO cai |
|--------------------|---------------|
| `kubeadm init` com as flags corretas | Configuração de módulos de kernel |
| `kubeadm join` para adicionar workers | Instalação do containerd do zero |
| `kubeadm token create --print-join-command` | Instalação e configuração do CNI do zero |
| `apt-mark hold` nos três pacotes | Configuração de sysctl |

**Sobre a instalação do CNI:**
> *"Não é uma competência obrigatória instalar CNI. Se cair alguma coisa relacionada, vão te dar um manifesto — você só precisa aplicar com `kubectl apply`. Nunca cai como: 'instale a Cilium do zero'."*

**O fluxo que você precisa ter mecânico:**
```
1. Adicionar repositório APT da version específica (ex: v1.32)
2. apt-get install -y kubeadm kubelet kubectl
3. apt-mark hold kubeadm kubelet kubectl
4. kubeadm init [flags]
5. Configurar kubeconfig
6. Instalar CNI (se necessário)
7. kubeadm join nos workers
```

**Conselho de estudo:**
> *"Crie quantos clusters conseguirem durante a semana. Destrua, recrie. O processo precisa ficar mecânico. A prova é uma prova de performance — cada minuto economizado é um minuto para revisar questões mais difíceis."*

---

## Armadilhas Mais Comuns

| Erro | Causa | Solução |
|------|-------|---------|
| `context deadline exceeded` no `init` | Kubelet usando IP de NAT em vez do IP da rede interna | Defina `--node-ip` em `/etc/default/kubelet`, execute `kubeadm reset -f` e reinicie |
| Node em `NotReady` após init | CNI não instalado | Instale o CNI antes de adicionar workers |
| `kubeadm join` com token inválido | Token expirado (> 24h) | `kubeadm token create --print-join-command` |
| apiserver não responde após editar manifest | Erro de sintaxe YAML | Reverta o arquivo ou corrija a sintaxe |
| `kubeconfig` não encontrado | Arquivo não copiado para `~/.kube/config` | `mkdir ~/.kube && cp /etc/kubernetes/admin.conf ~/.kube/config` |

---

## Recapitulando: A Ordem Completa

```
Em TODOS os nodes:
  1. Módulos de kernel (overlay, br_netfilter) — imediato + persistido
  2. Parâmetros sysctl (ip_forward, bridge-nf-call) — imediato + persistido
  3. Desabilitar swap — imediato + fstab
  4. Instalar containerd + SystemdCgroup = true
  5. Repositório APT Kubernetes (minor version correta)
  6. Instalar kubeadm, kubelet, kubectl + apt-mark hold
  7. Configurar node-ip no kubelet (se multi-interface)
  8. Configurar /etc/hosts

Somente no master:
  9. kubeadm init (flags diretas ou arquivo de configuração)
 10. Configurar kubeconfig (~/.kube/config)
 11. Instalar CNI

Em cada worker:
 12. kubeadm join (com token + hash do master)

Validação final:
 13. kubectl get nodes (todos Ready)
```

---

## Conclusão

Montar um cluster Kubernetes com kubeadm é um processo determinístico: cada passo tem uma causa e um efeito. Quando você entende **por que** o swap precisa estar desabilitado, por que o `SystemdCgroup` importa e por que o kubelet precisa do IP correto, você para de decorar comandos e começa a depurar.

Para a CKA, esse fluxo aparece como pré-requisito implícito em quase todos os cenários. Pratique o ciclo completo de destruir e recriar o cluster pelo menos duas vezes antes do exame.

No próximo artigo da série: **etcd backup e restore** — protegendo o estado do cluster antes de qualquer operação de risco.

---

**Recursos:**
- [CKA Curriculum Oficial v1.35](https://github.com/cncf/curriculum)
- [Documentação: Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Documentação: Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Documentação: Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

---

*Fazendo parte da série **Kubernetes Descomplicado** — documentando a jornada de estudo para a CKA com foco em entendimento real, não em memorização de comandos.*

---

### Tags sugeridas
`#Kubernetes` `#CKA` `#DevOps` `#CloudNative` `#SRE` `#Linux` `#kubeadm` `#containerd` `#Cilium` `#Infrastructure`
