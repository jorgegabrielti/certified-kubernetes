# Sub-tópico 01 — Provision Underlying Infrastructure

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Médio — aparece como pré-requisito implícito de quase todas as tarefas.

> [!IMPORTANT]
> **Atenção:** Absolutamente TODOS os passos descritos neste arquivo (Pré-requisitos de SO, Instalação do Containerd e Instalação dos pacotes Kubeadm/Kubelet) devem ser executados em **TODOS OS NÓS** do cluster (Master e Workers). A configuração inicial de infraestrutura é universal e idêntica para qualquer nó.

---

## Conceitos Fundamentais

### 1.1 Sistema Operacional

O Kubernetes exige um SO Linux com as seguintes condições satisfeitas **antes** de instalar qualquer componente:

| Requisito | Motivo |
|-----------|--------|
| Swap **desabilitado** | O kubelet não suporta swap por padrão; pode causar comportamento imprevisível de scheduling |
| `br_netfilter` carregado | Permite que iptables/nftables inspecionem tráfego de bridges (necessário para kube-proxy e CNI) |
| `ip_forward = 1` | Habilita roteamento IP entre interfaces — sem isso pods não se comunicam entre nodes |
| `overlay` carregado | Necessário para o driver de storage do containerd (OverlayFS) |

### 1.2 Módulos de Kernel

Os módulos precisam ser carregados **agora** e também persistidos para sobreviver a reboots:

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

### 1.3 Parâmetros sysctl

```bash
# Aplicar imediatamente
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system   # recarrega todos os arquivos em /etc/sysctl.d/
```

### 1.4 Desabilitar Swap

```bash
# Desabilitar imediatamente (sem reboot)
swapoff -a

# Persistir: comentar a linha de swap no fstab
sudo sed -i '/\sswap\s/s/^/#/' /etc/fstab
```

> **Dica de prova:** Na prova, o ambiente já vem configurado. Mas você pode precisar verificar que swap está off antes de fazer um `kubeadm init`. Use `swapon --show` — output vazio = OK.

---

## 2. Instalação do Container Runtime (containerd)

O Kubernetes não gerencia containers diretamente — ele delega ao **Container Runtime Interface (CRI)**. O `containerd` é o runtime padrão.

### 2.1 Instalar containerd

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

### 2.2 Gerar configuração padrão e habilitar SystemdCgroup

> **Crítico:** Sem `SystemdCgroup = true`, o kubelet e o containerd usarão cgroup drivers diferentes, causando falha de inicialização do node.

```bash
# Gerar config padrão
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Ativar SystemdCgroup (necessário para compatibilidade com kubelet)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Reiniciar e verificar
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd
```

### 2.3 Verificar socket CRI

```bash
# O kubelet se conecta ao containerd via socket Unix
ls -la /run/containerd/containerd.sock
```

---

## 3. Instalação de kubeadm, kubelet e kubectl

### 3.1 Configurar repositório APT do Kubernetes

> **Importante:** O repositório APT do Kubernetes é **por minor version**. Para instalar `v1.32.x`, você deve apontar para o repositório `v1.32`.

```bash
# Dependências do repositório
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Chave GPG
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Adicionar repositório (ajuste a minor version conforme necessário)
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /
EOF

sudo apt-get update
```

### 3.2 Instalar os pacotes

```bash
# Instalar versão específica (recomendado para controle)
sudo apt-get install -y kubeadm=1.32.0-1.1 kubelet=1.32.0-1.1 kubectl=1.32.0-1.1

# Fixar versão para evitar upgrade acidental
sudo apt-mark hold kubeadm kubelet kubectl
```

### 3.3 Configurar Node IP e Habilitar kubelet

> **Atenção (Vagrant/Multi-interfaces):** Se o seu node tem múltiplas placas de rede (ex: NAT e Host-Only), você **precisa** forçar o kubelet a escutar no IP da rede interna. Se pular isso, o `kubeadm init` falhará com erro de _timeout_ (`context deadline exceeded`) logo depois.

```bash
# Somente necessário se houver mais de uma interface de rede
echo "KUBELET_EXTRA_ARGS=--node-ip=<IP_INTERNO_DO_NODE>" | sudo tee /etc/default/kubelet

sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
# Nota: o kubelet ficará em loop de crash até o kubeadm init ser executado — isso é normal.
```

---

## 4. Configuração de Rede do Host

### 4.1 Endereços estáticos

Em ambientes de lab (Vagrant), cada node deve ter IP fixo para que os componentes do cluster se comuniquem de forma estável.

```bash
# Verificar IP de cada interface
ip addr show

# Verificar rota padrão
ip route
```

### 4.2 Resolução de nomes via /etc/hosts

> **Atenção:** Como delegamos a configuração da `private_network` para o Vagrant, suas VMs estão em uma rede Host-Only estável com os IPs amarrados abaixo. Caso não estivessem estáticos, você devia mapear o IP correto da segunda interface (jamais o IP de NAT).

```bash
cat <<EOF | sudo tee -a /etc/hosts
192.168.56.10  master01
192.168.56.11  worker01
192.168.56.12  worker02
EOF
```

> **Dica de prova:** Em alguns ambientes de prova, nodes já têm `/etc/hosts` configurado. Verifique antes de editar.

---

## 5. Verificações de Pré-requisitos (Checklist Rápido)

Execute este bloco no **início de cada sessão de lab** para validar o ambiente:

```bash
echo "=== Swap ===" && swapon --show
echo "=== br_netfilter ===" && lsmod | grep br_netfilter
echo "=== ip_forward ===" && sysctl net.ipv4.ip_forward
echo "=== overlay ===" && lsmod | grep overlay
echo "=== containerd ===" && systemctl is-active containerd
echo "=== kubelet ===" && kubelet --version
echo "=== kubeadm ===" && kubeadm version -o short
echo "=== kubectl ===" && kubectl version --client -o yaml | grep gitVersion
```

Resultado esperado:
- `swapon --show` → vazio
- `br_netfilter` e `overlay` → aparecem na listagem
- `net.ipv4.ip_forward = 1`
- `containerd` → `active`

---

## 6. Exercícios Práticos

### Básico

**Ex 1.1 — Validar pré-requisitos no node**
1. Confirmar que swap está desabilitado: `swapon --show` (deve estar vazio).
2. Confirmar módulos de kernel: `lsmod | grep br_netfilter`.
3. Confirmar ip_forward: `sysctl net.ipv4.ip_forward` (deve ser `1`).
4. Confirmar `containerd` rodando: `systemctl status containerd`.
5. Confirmar versões instaladas: `kubeadm version`, `kubelet --version`, `kubectl version --client`.

**Ex 1.2 — Identificar repositório APT configurado**
1. Listar repos: `cat /etc/apt/sources.list.d/kubernetes.list`.
2. Identificar a minor version configurada.
3. Responder: por que é necessário trocar o repo a cada upgrade de minor version?

### Intermediário

**Ex 1.3 — Configurar um node do zero (lab Vagrant)**
1. Destruir apenas o worker: `vagrant destroy worker01 -f`.
2. Recriar: `vagrant up worker01`.
3. Acessar o node: `vagrant ssh worker01`.
4. Aplicar todos os pré-requisitos manualmente (módulos, sysctl, swap, containerd, pacotes).
5. Validar com o checklist rápido da seção 5.

### Avançado

**Ex 1.4 — Diagnosticar node com pré-requisitos quebrados**
1. No worker01, re-habilitar swap: `swapon -a`.
2. Tentar adicionar o node ao cluster: `kubeadm join ...`.
3. Identificar a mensagem de erro do preflight.
4. Corrigir e repetir o join com sucesso.

---

## Armadilhas Comuns (Gotchas)

| Erro | Causa | Solução |
|------|-------|---------|
| `kubelet` em crash loop | `SystemdCgroup = false` no containerd | `sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && systemctl restart containerd` |
| Preflight falha em swap | Swap habilitado | `swapoff -a` e comentar linha no `/etc/fstab` |
| `br_netfilter` ausente | Módulo não carregado | `modprobe br_netfilter` |
| kubelet não conecta ao CRI | Socket incorreto | Verificar `--container-runtime-endpoint` no kubelet config |

---

## Dicas de Prova CKA

- Você **não** precisará provisionar um node do zero na prova — o ambiente já vem configurado.
- No entanto, pode ser pedido para **adicionar um worker** a um cluster existente — e o pré-requisito pode não estar configurado.
- Sempre use `systemctl status kubelet` para diagnóstico inicial quando um node não estiver `Ready`.
- O comando `journalctl -u kubelet -f` mostra logs em tempo real do kubelet.
