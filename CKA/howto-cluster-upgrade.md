# Cluster Upgrade com kubeadm

**Tópico CKA:** Cluster Architecture, Installation and Configuration (25%)

Este guia cobre o upgrade de um cluster kubeadm seguindo o procedimento oficial.
Execute cada etapa manualmente — é exatamente o que o exame CKA exige.

---

## Regras do upgrade

- **Nunca pule um minor version.** v1.31 → v1.32 → v1.33. Nunca v1.31 → v1.33.
- **Sempre faça backup do ETCD antes de qualquer upgrade.**
- **Sempre atualize o control plane antes dos workers.**
- **Um worker por vez** — nunca draine dois workers simultaneamente em produção.

---

## Fase 0 — Verificar ponto de partida

```bash
# Versão atual dos nodes
kubectl get nodes

# Versão dos componentes do control plane
kubectl version
kubeadm version

# Versão instalada dos pacotes
dpkg -l kubeadm kubelet kubectl | grep -E '^ii'

# Repositório APT atual
cat /etc/apt/sources.list.d/kubernetes.list
```

---

## Fase 1 — Backup do ETCD (obrigatório antes de qualquer upgrade)

```bash
# Verificar endpoint e certs
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Criar snapshot
sudo ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup-pre-upgrade.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Validar snapshot
sudo ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup-pre-upgrade.db \
  --write-out=table
```

---

## Fase 2 — Upgrade do Control Plane (master01)

> Execute todos os comandos a seguir **dentro de master01** via `vagrant ssh master01`.

### 2.1 — Trocar repositório APT para o minor version alvo

Substitua `v1.32` pela versão alvo do upgrade (ex.: v1.32, v1.33):

```bash
# Remover repositório anterior
sudo rm /etc/apt/sources.list.d/kubernetes.list

# Adicionar chave GPG e repositório da versão alvo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

### 2.2 — Ver versões disponíveis do kubeadm

```bash
sudo apt-cache madison kubeadm | head -10
```

Escolha a versão mais recente do minor version alvo (ex.: `1.32.x-1.1`).

### 2.3 — Atualizar kubeadm

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.32.x-1.1   # substitua x pela patch correta
sudo apt-mark hold kubeadm

kubeadm version
```

### 2.4 — Planejar e aplicar o upgrade

```bash
# Ver o que será atualizado
sudo kubeadm upgrade plan

# Aplicar (substitua pela versão exata disponível no plan)
sudo kubeadm upgrade apply v1.32.x
```

> O `kubeadm upgrade apply` atualiza: kube-apiserver, kube-controller-manager, kube-scheduler, kube-proxy, CoreDNS e o manifesto do ETCD. **Não atualiza kubelet nem kubectl.**

### 2.5 — Drain do control plane

```bash
# No host local ou em outro terminal com kubectl configurado
kubectl drain master01 --ignore-daemonsets --delete-emptydir-data
```

### 2.6 — Atualizar kubelet e kubectl

```bash
# Ainda dentro de master01
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.32.x-1.1 kubectl=1.32.x-1.1
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### 2.7 — Reabilitar o control plane

```bash
kubectl uncordon master01

# Validar
kubectl get nodes
```

---

## Fase 3 — Upgrade dos Worker Nodes (worker01, worker02, ...)

> Repita para **cada worker, um por vez**.

### 3.1 — Preparar o worker (execute no worker via `vagrant ssh workerXX`)

```bash
# Trocar repositório APT (mesma versão alvo do control plane)
sudo rm /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

# Atualizar kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.32.x-1.1
sudo apt-mark hold kubeadm

# Upgrade da configuração local do node
sudo kubeadm upgrade node
```

### 3.2 — Drain do worker (execute no host local ou master01)

```bash
kubectl drain worker01 --ignore-daemonsets --delete-emptydir-data
```

### 3.3 — Atualizar kubelet e kubectl no worker

```bash
# Dentro do worker
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.32.x-1.1 kubectl=1.32.x-1.1
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### 3.4 — Reabilitar o worker

```bash
kubectl uncordon worker01

# Validar
kubectl get nodes
```

---

## Fase 4 — Validação pós-upgrade

```bash
# Todos os nodes devem mostrar a nova versão e status Ready
kubectl get nodes -o wide

# Todos os pods do kube-system devem estar Running
kubectl get pods -n kube-system

# Cilium deve estar saudável
cilium status

# Versão dos componentes
kubectl version
```

---

## Fase 5 — Próximo minor version

Se o alvo final exigir mais de um salto (ex.: v1.31 → v1.32 → v1.33):

1. Repita **todas as fases** (0 a 4) trocando o repositório APT para o próximo minor.
2. Faça novo backup do ETCD antes de cada rodada.
3. Tire um snapshot Vagrant após cada minor version validado.

```bash
# No Windows, após validar cada versão:
vagrant snapshot save master01 post-upgrade-v1.32
vagrant snapshot save worker01 post-upgrade-v1.32
```

---

## Referências

- [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [ETCD backup and restore](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- Tópico CKA: **Cluster Architecture, Installation and Configuration — 25%**
