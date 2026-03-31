# Guia Pratico: Upgrade de Cluster Kubernetes com Kubeadm

Referencia: [CKA Curriculum v1.35](./CKA_Curriculum_v1.35.pdf) — dominio Cluster Architecture, Installation and Configuration (25%)

> Execute sempre o backup do ETCD antes de iniciar qualquer upgrade.
> Siga a ordem obrigatoria: control plane primeiro, workers um por vez.

---

## Pre-requisitos

- Cluster ativo com `kubectl get nodes` mostrando todos os nodes `Ready`.
- Acesso SSH ao master01 e worker01 via `vagrant ssh`.
- ETCD backup realizado (ver fase 1.1 abaixo).

---

## Fase 1 — Backup do ETCD (obrigatorio antes do upgrade)

**1.1 — Criar snapshot**
```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/cka-pre-upgrade.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**1.2 — Validar integridade do snapshot**
```bash
ETCDCTL_API=3 etcdctl snapshot status /tmp/cka-pre-upgrade.db --write-out=table
```

---

## Fase 2 — Upgrade do Control Plane (master01)

Execute cada passo no master01: `vagrant ssh master01` seguido de `sudo -i`.

**2.1 — Verificar versao atual**
```bash
kubectl get nodes
kubeadm version
kubelet --version
kubectl version --client
```

**2.2 — Identificar proxima versao disponivel**
```bash
# Listar versoes disponiveis do kubeadm para o proximo minor
apt-cache madison kubeadm | head -5
```

**2.3 — Atualizar repositorio APT para o proximo minor version**
```bash
# Exemplo: trocar para v1.32 (ajuste conforme a versao alvo)
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list
apt-get update
```

**2.4 — Instalar novo kubeadm**
```bash
apt-get install -y kubeadm=1.32.0-1.1   # substitua pela versao alvo
kubeadm version
```

**2.5 — Verificar plano de upgrade**
```bash
kubeadm upgrade plan
```

**2.6 — Aplicar o upgrade no control plane**
```bash
kubeadm upgrade apply v1.32.0   # substitua pela versao alvo
```

**2.7 — Atualizar kubelet e kubectl no master01**
```bash
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
systemctl daemon-reload
systemctl restart kubelet
# Validar
kubectl get nodes
```

---

## Fase 3 — Upgrade do Worker (worker01)

Execute os passos 3.1–3.2 no master01 e 3.3–3.4 no worker01.

**3.1 — Drenar o worker (a partir do master01)**
```bash
kubectl drain worker01 --ignore-daemonsets --delete-emptydir-data
```

**3.2 — Verificar que worker01 esta em estado SchedulingDisabled**
```bash
kubectl get nodes
# worker01 deve aparecer como Ready,SchedulingDisabled
```

**3.3 — Atualizar kubeadm, kubelet e kubectl no worker01**
```bash
# No worker01 (vagrant ssh worker01 ; sudo -i)
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubeadm=1.32.0-1.1
kubeadm upgrade node
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
systemctl daemon-reload
systemctl restart kubelet
```

**3.4 — Reabilitar o worker (a partir do master01)**
```bash
kubectl uncordon worker01
kubectl get nodes
# Ambos devem aparecer como Ready na nova versao
```

---

## Validacao Final

```bash
kubectl get nodes -o wide
kubectl get pods -A
# ETCD deve estar saudavel
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## Repita para cada minor version

Se o objetivo for upgrades encadeados (ex: v1.31 → v1.32 → v1.33):
1. Execute as fases 1–3 completas para cada minor version.
2. Nao pule minor versions — o kubeadm nao suporta upgrade de mais de um minor por vez.
3. Atualize o repositorio APT (`sed -i`) antes de cada ciclo.
