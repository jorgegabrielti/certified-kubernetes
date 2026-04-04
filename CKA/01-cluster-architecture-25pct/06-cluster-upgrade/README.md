# Sub-tópico 06 — Perform a Version Upgrade on a Kubernetes Cluster Using Kubeadm

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — tarefa frequente na prova, com sequência de passos bem definida e cronometrada.

---

## Conceitos Fundamentais

### 6.1 Regras de Upgrade

O Kubernetes tem regras estritas de compatibilidade de versão:

| Regra | Detalhe |
|-------|---------|
| **Um minor por vez** | Não é permitido pular minor versions (ex: 1.30 → 1.32 sem passar por 1.31) |
| **Control plane primeiro** | Sempre faça upgrade do(s) control plane node(s) antes dos workers |
| **Workers um por vez** | Drenar → fazer upgrade → uncordon → próximo |
| **Repositório APT por minor** | O repo do Kubernetes é versionado por minor; é necessário trocar a cada upgrade |

### 6.2 Componentes atualizados por cada ferramenta

| Ferramenta | O que atualiza |
|------------|---------------|
| `kubeadm upgrade apply` | Static pod manifests (apiserver, controller-manager, scheduler, etcd) |
| `apt-get install kubelet kubectl` | Os binários no node |
| `systemctl restart kubelet` | Aplica a nova versão do kubelet |

---

## 7. Sequência de Upgrade — Visão Geral

```
1. Backup do ETCD           ← SEMPRE antes de qualquer upgrade
2. Identificar versão alvo  ← apt-cache madison kubeadm
3. Atualizar repositório APT
4. Upgrade do control plane
   a. Instalar novo kubeadm
   b. kubeadm upgrade plan
   c. kubeadm upgrade apply
   d. Atualizar kubelet + kubectl no master
   e. Reiniciar kubelet
5. Para cada worker:
   a. kubectl drain <worker>
   b. Atualizar kubeadm + kubelet + kubectl no worker
   c. kubeadm upgrade node
   d. Reiniciar kubelet
   e. kubectl uncordon <worker>
6. Validação final
```

---

## 8. Fase 1 — Backup do ETCD (Pré-requisito Obrigatório)

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/pre-upgrade-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Validar
ETCDCTL_API=3 etcdctl snapshot status /tmp/pre-upgrade-$(date +%Y%m%d).db --write-out=table
```

---

## 9. Fase 2 — Upgrade do Control Plane (master01)

Execute todos os passos como `root` no master01: `vagrant ssh master01` → `sudo -i`

### 9.1 Verificar versão atual

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
kubectl version --client -o yaml | grep gitVersion
```

### 9.2 Identificar próxima versão disponível

```bash
# Listar versões disponíveis do kubeadm no repositório atual
apt-cache madison kubeadm | head -10
```

### 9.3 Atualizar repositório APT

```bash
# Exemplo: subindo de v1.31 para v1.32
# Editar o arquivo de repo (substituir a minor version)
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list

# Verificar que a mudança foi aplicada
cat /etc/apt/sources.list.d/kubernetes.list

apt-get update
```

### 9.4 Instalar novo kubeadm

```bash
# Desbloquear o pacote temporariamente
apt-mark unhold kubeadm

# Instalar a versão alvo
apt-get install -y kubeadm=1.32.0-1.1    # substituir pela versão alvo

# Re-bloquear
apt-mark hold kubeadm

# Confirmar versão instalada
kubeadm version -o short
```

### 9.5 Verificar plano de upgrade

```bash
kubeadm upgrade plan
```

O output mostrará:
- Versão atual do cluster
- Versão alvo disponível
- Componentes que serão atualizados

### 9.6 Aplicar o upgrade no control plane

> **Atenção à Sintaxe (Armadilha CKA):** O `kubeadm` **não** reconhece o sufixo do instalador de pacotes Ubuntu (`-1.1`). Passar esse sufixo fará o comando falhar acusando repasse de "versão instável (unstable)". O comando abaixo usa apenas SemVer puro (ex: `v1.35.2`).

```bash
kubeadm upgrade apply v1.32.0 --yes   # substituir pela versão alvo exata
```

Este comando:
- Atualiza os static pod manifests de todos os componentes do control plane
- Reinicia os pods correspondentes automaticamente

### 9.7 Atualizar kubelet e kubectl no master

```bash
# Desbloquear
apt-mark unhold kubelet kubectl

# Instalar
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1

# Re-bloquear
apt-mark hold kubelet kubectl

# Recarregar daemon e reiniciar kubelet
systemctl daemon-reload
systemctl restart kubelet

# Verificar
kubectl get nodes
# master01 deve aparecer na nova versão
```

---

## 10. Fase 3 — Upgrade dos Workers

Repita para cada worker, um de cada vez.

### 10.1 Drenar o worker (executar no master)

```bash
# Cordonar e esvaziar o node
# --ignore-daemonsets: DaemonSets não são bloqueantes
# --delete-emptydir-data: permite remover pods com emptyDir
kubectl drain worker01 --ignore-daemonsets --delete-emptydir-data

# Verificar que está em SchedulingDisabled
kubectl get nodes
```

### 10.2 Atualizar kubeadm, kubelet e kubectl no worker

```bash
# Acessar o worker
vagrant ssh worker01
sudo -i

# Trocar repositório APT
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list
apt-get update

# Instalar kubeadm
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.32.0-1.1
apt-mark hold kubeadm

# Aplicar upgrade no node worker
kubeadm upgrade node

# Instalar kubelet e kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl

# Reiniciar kubelet
systemctl daemon-reload
systemctl restart kubelet
```

### 10.3 Reabilitar o worker (executar no master)

```bash
kubectl uncordon worker01

# Verificar que voltou a Ready
kubectl get nodes
```

---

## 11. Validação Final

```bash
# Todos os nodes devem estar Ready na nova versão
kubectl get nodes -o wide

# Todos os pods do sistema devem estar Running
kubectl get pods -n kube-system

# ETCD deve estar saudável
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Testar criação de recurso
kubectl create deployment test --image=nginx --replicas=2
kubectl get pods
kubectl delete deployment test
```

---

## 12. Exercícios Práticos

### Básico

**Ex 6.1 — Identificar versão e disponibilidade de upgrade**
1. Verificar versão atual: `kubectl get nodes` e `kubeadm version`.
2. Verificar próxima versão disponível: `apt-cache madison kubeadm | head -5`.
3. Executar `kubeadm upgrade plan` e interpretar o output.
4. Identificar qual minor version está no repositório APT: `cat /etc/apt/sources.list.d/kubernetes.list`.

### Intermediário

**Ex 6.2 — Upgrade completo de 1 minor version**
1. Fazer backup ETCD.
2. Trocar repositório APT para o próximo minor.
3. Atualizar kubeadm no master → `kubeadm upgrade apply`.
4. Atualizar kubelet e kubectl no master.
5. Drenar worker01 → atualizar → uncordon.
6. Validar que todos os nodes estão na nova versão.

### Avançado

**Ex 6.3 — Upgrade encadeado (2 minor versions)**
1. Identificar a versão atual (ex: v1.29).
2. Executar ciclo completo para v1.30.
3. Executar ciclo completo para v1.31.
4. Cronometrar cada ciclo (meta: < 20 minutos por minor version).
5. Registrar quaisquer erros encontrados e como foram resolvidos.

---

## Referência Rápida — Sequência para Prova

```bash
# ═══ MASTER ══════════════════════════════════════════════════════════════════

# 1. Backup ETCD (obrigatório)
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-pre-upgrade.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 2. Trocar repo APT (ajustar versões)
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list && apt-get update

# 3. Upgrade kubeadm
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.32.0-1.1 && apt-mark hold kubeadm

# 4. Planejar e aplicar upgrade
kubeadm upgrade plan
kubeadm upgrade apply v1.32.0

# 5. Upgrade kubelet + kubectl no master
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# ═══ WORKER (repetir para cada worker) ═══════════════════════════════════════

# 6. Drenar (no master)
kubectl drain worker01 --ignore-daemonsets --delete-emptydir-data

# 7. No worker01:
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list && apt-get update
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.32.0-1.1 && apt-mark hold kubeadm
kubeadm upgrade node
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# 8. Uncordon (no master)
kubectl uncordon worker01
kubectl get nodes
```

---

## Armadilhas Comuns (Gotchas)

| Erro | Causa | Solução |
|------|-------|---------|
| `kubeadm upgrade apply` acusa versão *unstable* ou inválida | Inclusão do sufixo do APT (`-1.1`) no valor passado ao `kubeadm` | O `kubeadm` exige o "v" inicial e recusa sufixos. O `-1.1` (sem "v") no final é de uso estritamente exclusivo do `apt-get install` no Ubuntu. |
| `kubeadm upgrade apply` falha com "version mismatch" | Tentativa de pular minor version | Fazer upgrade uma minor version por vez |
| Node fica em `SchedulingDisabled` após uncordon | uncordon não foi executado | `kubectl uncordon <node>` |
| `apt-get install kubeadm=X` não encontra versão | Repositório apontando para minor errada | Verificar e corrigir `/etc/apt/sources.list.d/kubernetes.list` |
| kubelet não reinicia | Versão incompatível instalada | Verificar `journalctl -u kubelet` para identificar o erro |
| worker ainda usa versão antiga após upgrade | kubelet não reiniciou | `systemctl daemon-reload && systemctl restart kubelet` |

---

## Dicas de Prova CKA

- **Sempre fazer backup ETCD antes de iniciar** — se der errado, você pode restaurar.
- O comando `kubeadm upgrade apply` **só funciona no control plane** — no worker, use `kubeadm upgrade node`.
- Lembre-se: **`apt-mark unhold` antes** de instalar e **`apt-mark hold` depois**.
- Use `kubectl get nodes -w` para monitorar o status em tempo real durante o upgrade do kubelet.
- Se a prova pedir para fazer upgrade "to the latest patch version", use `kubeadm upgrade plan` para descobrir qual é.
- Meta de tempo: **< 20 minutos por minor version** para garantir confortabilidade na prova de 2 horas.
