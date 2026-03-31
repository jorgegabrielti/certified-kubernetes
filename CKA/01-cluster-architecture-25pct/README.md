# Cluster Architecture, Installation and Configuration — 25%

Referencia: [CKA Curriculum v1.35](../CKA_Curriculum_v1.35.pdf)

---

## Sub-topicos

| # | Topico | Peso estimado |
|---|--------|---------------|
| 1 | Manage role based access control (RBAC) | Alto |
| 2 | Use Kubeadm to install a basic cluster | Alto |
| 3 | Manage a highly-available Kubernetes cluster | Medio |
| 4 | Provision underlying infrastructure to deploy a Kubernetes cluster | Medio |
| 5 | Perform a version upgrade on a Kubernetes cluster using Kubeadm | Alto |
| 6 | Implement etcd backup and restore | Alto |

---

## 1. RBAC

### Conceitos
- `Role` e `RoleBinding` — escopo de namespace
- `ClusterRole` e `ClusterRoleBinding` — escopo de cluster
- `ServiceAccount` — identidade de pods e workloads
- `kubectl auth can-i` — verificacao de permissoes

### Exercicios

**1.1 — Criar ServiceAccount + Role + RoleBinding**
1. Criar namespace `rbac-lab`.
2. Criar `ServiceAccount` `app-sa` no namespace `rbac-lab`.
3. Criar `Role` `app-role` que permite `get`, `list`, `watch` em `pods` e `services`.
4. Criar `RoleBinding` `app-rb` vinculando `app-sa` a `app-role`.
5. Validar: `kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab`
6. Validar negacao: `kubectl auth can-i delete pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab`

**1.2 — ClusterRole para acesso somente-leitura**
1. Criar `ClusterRole` `readonly-nodes` que permite `get`, `list`, `watch` em `nodes`.
2. Criar usuario ficticio `dev-user` (via `ClusterRoleBinding`).
3. Validar acesso: `kubectl auth can-i list nodes --as=dev-user`
4. Validar negacao: `kubectl auth can-i delete nodes --as=dev-user`

**1.3 — Diagnosticar e corrigir RBAC quebrado**
1. Criar `Deployment` cuja aplicacao chama a API do Kubernetes (ex: `bitnami/kubectl`).
2. Intencionalmente remover a permissao necessaria.
3. Identificar o erro via `kubectl logs` e `kubectl describe pod`.
4. Corrigir adicionando a permissao correta na `Role`.

---

## 2. Instalacao com Kubeadm

Referencia: [howto-cluster-upgrade.md](../howto-cluster-upgrade.md)

### Conceitos
- Fases do `kubeadm init` (preflight, certs, kubeconfig, manifests, addons)
- `--pod-network-cidr` e escolha de CNI
- Arquivo de configuracao kubeadm (`KubeadmConfig`)
- `kubeadm join` com token e discovery hash

### Exercicios

**2.1 — Inicializar cluster do zero (lab Vagrant)**
1. Destruir e recriar o lab: `vagrant destroy -f && vagrant up master01`.
2. Confirmar que o control plane sobe sem erros de preflight.
3. Instalar CNI (Cilium ou Flannel).
4. Executar `kubeadm join` no worker01.
5. Validar: `kubectl get nodes` mostra ambos `Ready`.

**2.2 — Gerar novo token de join**
1. Listar tokens existentes: `kubeadm token list`.
2. Criar novo token: `kubeadm token create --print-join-command`.
3. Usar o novo token para re-adicionar o worker (apos `kubeadm reset` e `kubeadm join`).

**2.3 — Inspecionar manifestos do control plane**
1. Localizar os manifestos estaticos: `ls /etc/kubernetes/manifests/`.
2. Identificar flags criticas de cada componente (apiserver, controller-manager, scheduler, etcd).
3. Alterar uma flag nao-critica do apiserver e confirmar que ele reinicia automaticamente.
4. Reverter a alteracao.

---

## 3. Alta Disponibilidade (HA)

### Conceitos
- Topologia stacked etcd vs external etcd
- Load balancer externo para o kube-apiserver
- Adicionar segundo control plane com `kubeadm join --control-plane`
- `kubeadm init --control-plane-endpoint`

### Exercicios

**3.1 — Planejar topologia HA**
1. Listar os componentes que precisam ser redundantes num cluster HA.
2. Identificar o endpoint do load balancer no kubeconfig atual.
3. Verificar quantos members o etcd teria num cluster de 3 control planes.
4. Descrever o impacto de perder 1 de 3 etcd members (quorum).

> Nota: este exercicio pode ser teorico se o lab tiver apenas 1 control plane.

---

## 4. Upgrade com Kubeadm

Referencia: [howto-cluster-upgrade.md](../howto-cluster-upgrade.md)

### Conceitos
- Sequencia obrigatoria: control plane → workers (um por vez)
- `kubeadm upgrade plan` — identifica versao disponivel
- `kubeadm upgrade apply` — aplica no control plane
- `kubectl drain` / `kubectl uncordon`
- Troca de repositorio APT para cada minor version

### Exercicios

**4.1 — Upgrade completo do cluster (Lista 1)**
1. Verificar versao atual: `kubectl get nodes`.
2. Fazer backup ETCD antes de qualquer upgrade (ver secao 5 abaixo).
3. Atualizar repositorio APT para o proximo minor.
4. No master01: `apt-get install kubeadm=<versao>`, `kubeadm upgrade apply <versao>`.
5. Atualizar `kubelet` e `kubectl` no master01, reiniciar kubelet.
6. Drenar worker01, atualizar `kubeadm`, `kubelet`, `kubectl`, reiniciar kubelet, uncordon.
7. Repetir ciclo para cada minor version ate a mais recente.

**4.2 — Upgrade simulado em ambiente de prova**
1. Identificar a versao mais recente disponivel: `apt-cache madison kubeadm`.
2. Executar `kubeadm upgrade plan` e registrar o output.
3. Cronometrar o ciclo completo de upgrade (meta: < 20 minutos por minor version).

---

## 5. Backup e Restore do ETCD

### Conceitos
- `etcdctl snapshot save` — criacao do snapshot
- `etcdctl snapshot restore` — restauracao para diretorio novo
- Atualizar manifesto do etcd para apontar para o diretorio restaurado
- Verificar saude: `etcdctl endpoint health`

### Exercicios

**5.1 — Backup do ETCD**
```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/cka-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verificar integridade
ETCDCTL_API=3 etcdctl snapshot status /tmp/cka-snapshot.db --write-out=table
```

**5.2 — Restore do ETCD**
1. Criar alguns recursos de teste (Deployment, ConfigMap, Service).
2. Fazer backup do ETCD.
3. Deletar os recursos criados.
4. Restaurar o snapshot:
```bash
ETCDCTL_API=3 etcdctl snapshot restore /tmp/cka-snapshot.db \
  --data-dir=/var/lib/etcd-restore \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```
5. Editar `/etc/kubernetes/manifests/etcd.yaml` — alterar `hostPath` de `/var/lib/etcd` para `/var/lib/etcd-restore`.
6. Aguardar etcd reiniciar e validar que os recursos retornaram.

---

## Checklist de Dominio

- [ ] Criar Role/ClusterRole e validar com `auth can-i`
- [ ] Instalar cluster do zero com kubeadm
- [ ] Gerar token de join e adicionar worker
- [ ] Fazer upgrade de pelo menos 1 minor version (end-to-end)
- [ ] Fazer backup ETCD, deletar recursos, restaurar e validar
- [ ] Cronometrar ciclo completo de upgrade (meta < 20 min)
