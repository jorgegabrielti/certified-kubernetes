# Sub-tópico 02 — Use Kubeadm to Install a Basic Cluster

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — aparece diretamente em tarefas de inicialização de cluster e adição de nodes.

---

## Conceitos Fundamentais

### 2.1 O que é o kubeadm?

O `kubeadm` é a ferramenta oficial para **bootstrapping de clusters Kubernetes**. Ele automatiza:
- Geração de certificados TLS para todos os componentes
- Criação de arquivos kubeconfig
- Geração dos static pod manifests (apiserver, etcd, controller-manager, scheduler)
- Configuração inicial do RBAC e addons (CoreDNS, kube-proxy)

### 2.2 Fases do `kubeadm init`

O `kubeadm init` executa as seguintes fases em ordem:

| Fase | O que acontece |
|------|----------------|
| `preflight` | Valida pré-requisitos (swap, módulos, CRI, portas) |
| `certs` | Gera a CA e todos os certificados TLS em `/etc/kubernetes/pki/` |
| `kubeconfig` | Cria `admin.conf`, `kubelet.conf`, `controller-manager.conf`, `scheduler.conf` |
| `etcd` | Cria o static pod manifest do etcd |
| `control-plane` | Cria manifests do apiserver, controller-manager e scheduler |
| `kubelet-start` | Configura e inicia o kubelet no control plane |
| `upload-config` | Salva a configuração do kubeadm como ConfigMap no cluster |
| `mark-control-plane` | Adiciona taint `node-role.kubernetes.io/control-plane` ao node |
| `bootstrap-token` | Cria o token para join de workers |
| `addons` | Instala CoreDNS e kube-proxy |

### 2.3 CIDR de Pods e Escolha de CNI

O `--pod-network-cidr` define o range de IPs que será alocado para os pods. **Cada CNI exige um range específico** ou tem um padrão:

| CNI | CIDR padrão recomendado |
|-----|------------------------|
| Cilium | `10.244.0.0/16` (recomendado) |
| Calico | `192.168.0.0/16` |
| Flannel | `10.244.0.0/16` |
| Weave | Automático |

> **Dica de prova:** Use **Cilium** se a prova não especificar o CNI — é o CNI adotado neste lab. Cilium suporta eBPF e não depende de `kube-proxy`, mas para a CKA o foco é na instalação, não em features avançadas.

### 2.4 Static Pod Manifests

Os componentes do control plane rodam como **static pods** — pods gerenciados diretamente pelo kubelet, sem passar pelo apiserver.

- Localização: `/etc/kubernetes/manifests/`
- Arquivos: `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`, `etcd.yaml`
- **Qualquer alteração nesses arquivos é detectada automaticamente pelo kubelet**, que reinicia o pod correspondente.

---

## 3. Inicializando o Cluster

### 3.1 Usando flags diretas (forma simples)

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.56.10  # IP do control plane
```

### 3.2 Usando arquivo de configuração (forma declarativa — preferida para prova)

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
kubeadm init --config kubeadm-config.yaml
```

### 3.3 Configurar o kubeconfig para kubectl

Após o `kubeadm init`, copie o kubeconfig para o home do usuário:

```bash
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Verificar acesso
kubectl get nodes
```

### 3.4 Instalar CNI (Cilium)

A forma recomendada é via **Cilium CLI**:

```bash
# Instalar a Cilium CLI (executar uma vez por host)
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar -xzvf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Instalar Cilium no cluster (apontando host explicitamente por causa do multi-interface)
cilium install \
  --set k8sServiceHost=192.168.56.10 \
  --set k8sServicePort=6443

# Verificar status (aguardar todos os pods ficarem Running)
cilium status --wait
```

Alternativamente, via Helm:

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system
```

### 3.5 Verificar status dos componentes

```bash
# Nodes do cluster
kubectl get nodes

# Pods do control plane
kubectl get pods -n kube-system

# Status dos componentes
kubectl get componentstatuses   # deprecated em versões recentes, mas ainda útil
```

---

## 4. Adicionando Workers ao Cluster (`kubeadm join`)

### 4.1 Comando de join gerado pelo `kubeadm init`

Ao final do `kubeadm init`, o output inclui o comando de join:

```bash
kubeadm join 192.168.56.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:<hash>
```

### 4.2 Gerar novo token (se o original expirou)

Tokens de join expiram em **24 horas** por padrão.

```bash
# Listar tokens existentes
kubeadm token list

# Criar novo token e imprimir o comando de join completo
kubeadm token create --print-join-command

# Obter o discovery hash (alternativa manual)
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'
```

### 4.3 Executar join no worker

```bash
# No worker01 (como root)
kubeadm join 192.168.56.10:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

```bash
# Verificar no master (após alguns segundos)
kubectl get nodes
# worker01 deve aparecer como Ready
```

---

## 5. Inspecionando os Static Pod Manifests

### 5.1 Listar manifests

```bash
ls -la /etc/kubernetes/manifests/
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml
# etcd.yaml
```

### 5.2 Flags críticas do kube-apiserver

```bash
grep -E '^\s+\-\-' /etc/kubernetes/manifests/kube-apiserver.yaml | head -20
```

Flags importantes a conhecer:

| Flag | Propósito |
|------|-----------|
| `--advertise-address` | IP que o apiserver anuncia para o cluster |
| `--etcd-servers` | Endpoint do etcd |
| `--service-cluster-ip-range` | CIDR dos Services ClusterIP |
| `--authorization-mode` | Modos de autorização (Node,RBAC) |
| `--tls-cert-file` / `--tls-private-key-file` | Certificados do apiserver |

### 5.3 Alterar e reverter uma flag (exercício)

```bash
# Editar o manifest (o kubelet detecta a mudança automaticamente)
vim /etc/kubernetes/manifests/kube-apiserver.yaml

# Aguardar o pod reiniciar (~30s)
watch kubectl get pods -n kube-system

# Verificar se o apiserver voltou a responder
kubectl cluster-info
```

> **Atenção:** Nunca use `kubectl delete pod` em static pods do control plane — eles serão recriados automaticamente pelo kubelet.

---

## 6. Exercícios Práticos

### Básico

**Ex 2.1 — Inspecionar um cluster existente**
1. Listar todos os nodes: `kubectl get nodes -o wide`.
2. Verificar a versão do cluster: `kubectl version`.
3. Listar os static pod manifests: `ls /etc/kubernetes/manifests/`.
4. Identificar o CIDR de pods configurado: `kubectl cluster-info dump | grep -i cidr`.

**Ex 2.2 — Listar e verificar tokens de join**
1. Listar tokens: `kubeadm token list`.
2. Verificar expiração de cada token.
3. Criar um novo token: `kubeadm token create --print-join-command`.

### Intermediário

**Ex 2.3 — Inicializar cluster do zero (lab Vagrant)**
1. Destruir e recriar o lab: `vagrant destroy -f && vagrant up`.
2. No master01: executar `kubeadm init` com CIDR correto.
3. Configurar kubeconfig.
4. Instalar CNI.
5. Adicionar worker01 com `kubeadm join`.
6. Validar: `kubectl get nodes` mostrando ambos `Ready`.

### Avançado

**Ex 2.4 — Reinicializar cluster com arquivo de configuração YAML**
1. Criar o arquivo `kubeadm-config.yaml` (ver seção 3.2).
2. Executar `kubeadm init --config kubeadm-config.yaml`.
3. Verificar que as configurações declaradas foram aplicadas.
4. Localizar o ConfigMap salvo: `kubectl get cm kubeadm-config -n kube-system -o yaml`.

**Ex 2.5 — Diagnosticar control plane com falha**
1. Excluir intencionalmente o manifesto do scheduler: `mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/`.
2. Tentar criar um Deployment e verificar que os pods ficam em `Pending`.
3. Restaurar o manifesto: `mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/`.
4. Confirmar que o scheduler volta e os pods saem do estado `Pending`.

---

## Armadilhas Comuns (Gotchas)

| Erro | Causa | Solução |
|------|-------|---------|
| `context deadline exceeded` no `init` | Kubelet subiu na interface errada (ex: IP de NAT) | Ocorreu um *split-brain*. Limpe com `sudo kubeadm reset -f`, defina o `--node-ip` no `/etc/default/kubelet` e reinicie. |
| Nodes em `NotReady` após init | CNI não instalado | Instalar CNI antes de adicionar workers |
| `kubeadm join` com token inválido | Token expirado (> 24h) | `kubeadm token create --print-join-command` |
| apiserver não responde após editar manifest | Erro de sintaxe YAML | Verificar sintaxe com `kubectl --validate=false` ou reverter backup |
| `kubeconfig` não encontrado | Arquivo não copiado | `mkdir ~/.kube && cp /etc/kubernetes/admin.conf ~/.kube/config` |

---

## Dicas de Prova CKA

- **Guarde o output do `kubeadm init`** — o comando de join está lá.
- Se precisar do join command depois, use `kubeadm token create --print-join-command` (mais rápido que reconstruir manualmente).
- Em ambientes de prova, o `kubeconfig` geralmente já está configurado. Se não estiver, copie de `/etc/kubernetes/admin.conf`.
- Use `kubectl get pods -n kube-system -w` para monitorar a subida dos componentes após alterações.
- O comando `kubeadm reset` desfaz completamente a inicialização — útil para recomeçar em caso de erro.
