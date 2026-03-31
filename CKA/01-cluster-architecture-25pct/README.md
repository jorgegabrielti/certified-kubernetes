# Cluster Architecture, Installation and Configuration — 25%

Referencia: [CKA Curriculum v1.35](../CKA_Curriculum_v1.35.pdf)

---

## Sub-topicos

Ordem logica de estudo (pre-requisito → derivado):

| # | Topico | Peso estimado |
|---|--------|---------------|
| 1 | Provision underlying infrastructure to deploy a Kubernetes cluster | Medio |
| 2 | Use Kubeadm to install a basic cluster | Alto |
| 3 | Manage role based access control (RBAC) | Alto |
| 4 | Manage a highly-available Kubernetes cluster | Medio |
| 5 | Implement etcd backup and restore | Alto |
| 6 | Perform a version upgrade on a Kubernetes cluster using Kubeadm | Alto |

---

## 1. Provision underlying infrastructure

### Conceitos
- Requisitos de SO: swap desabilitado, br_netfilter, ip_forward
- Pacotes essenciais: `containerd`, `kubeadm`, `kubelet`, `kubectl`
- Repositorio APT do Kubernetes (por minor version)
- Configuracao do `containerd` com `SystemdCgroup = true`
- Rede host: enderecos estaticos, resolucao de nomes (`/etc/hosts`)

### Exercicios

**1.1 — Validar pre-requisitos no node**
1. Confirmar que swap esta desabilitado: `swapon --show` (deve estar vazio).
2. Confirmar modulos de kernel: `lsmod | grep br_netfilter`.
3. Confirmar ip_forward: `sysctl net.ipv4.ip_forward` (deve ser `1`).
4. Confirmar `containerd` rodando: `systemctl status containerd`.
5. Confirmar versoes instaladas: `kubeadm version`, `kubelet --version`, `kubectl version --client`.

**1.2 — Recriar um node do zero (lab Vagrant)**
1. Destruir apenas o worker: `vagrant destroy worker01 -f`.
2. Recriar: `vagrant up worker01`.
3. Validar que todos os pre-requisitos acima estao satisfeitos apos o provision.

**1.3 — Identificar repositorio APT configurado**
1. Listar repos: `cat /etc/apt/sources.list.d/kubernetes.list`.
2. Identificar a minor version configurada.
3. Entender por que e necessario trocar o repo a cada upgrade de minor version.

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

## 3. RBAC

### Conceitos
- `Role` e `RoleBinding` — escopo de namespace
- `ClusterRole` e `ClusterRoleBinding` — escopo de cluster
- `ServiceAccount` — identidade de pods e workloads
- `kubectl auth can-i` — verificacao de permissoes

### Exercicios

**3.1 — Criar ServiceAccount + Role + RoleBinding**
1. Criar namespace `rbac-lab`.
2. Criar `ServiceAccount` `app-sa` no namespace `rbac-lab`.
3. Criar `Role` `app-role` que permite `get`, `list`, `watch` em `pods` e `services`.
4. Criar `RoleBinding` `app-rb` vinculando `app-sa` a `app-role`.
5. Validar: `kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab`
6. Validar negacao: `kubectl auth can-i delete pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab`

**3.2 — ClusterRole para acesso somente-leitura**
1. Criar `ClusterRole` `readonly-nodes` que permite `get`, `list`, `watch` em `nodes`.
2. Criar usuario ficticio `dev-user` (via `ClusterRoleBinding`).
3. Validar acesso: `kubectl auth can-i list nodes --as=dev-user`
4. Validar negacao: `kubectl auth can-i delete nodes --as=dev-user`

**3.3 — Diagnosticar e corrigir RBAC quebrado**
1. Criar `Deployment` cuja aplicacao chama a API do Kubernetes (ex: `bitnami/kubectl`).
2. Intencionalmente remover a permissao necessaria.
3. Identificar o erro via `kubectl logs` e `kubectl describe pod`.
4. Corrigir adicionando a permissao correta na `Role`.

---

## 4. Alta Disponibilidade (HA)

### Conceitos
- Topologia stacked etcd vs external etcd
- Load balancer externo para o kube-apiserver
- Adicionar segundo control plane com `kubeadm join --control-plane`
- `kubeadm init --control-plane-endpoint`

### Exercicios

**4.1 — Planejar topologia HA**
1. Listar os componentes que precisam ser redundantes num cluster HA.
2. Identificar o endpoint do load balancer no kubeconfig atual.
3. Verificar quantos members o etcd teria num cluster de 3 control planes.
4. Descrever o impacto de perder 1 de 3 etcd members (quorum).

> Nota: este exercicio pode ser teorico se o lab tiver apenas 1 control plane.

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

## 6. Upgrade com Kubeadm

Referencia: [howto-cluster-upgrade.md](../howto-cluster-upgrade.md)

### Conceitos
- Sequencia obrigatoria: control plane → workers (um por vez)
- `kubeadm upgrade plan` — identifica versao disponivel
- `kubeadm upgrade apply` — aplica no control plane
- `kubectl drain` / `kubectl uncordon`
- Troca de repositorio APT para cada minor version

### Exercicios

**6.1 — Upgrade completo do cluster (Lista 1)**
1. Verificar versao atual: `kubectl get nodes`.
2. Fazer backup ETCD antes de qualquer upgrade (ver secao 5 acima).
3. Atualizar repositorio APT para o proximo minor.
4. No master01: `apt-get install kubeadm=<versao>`, `kubeadm upgrade apply <versao>`.
5. Atualizar `kubelet` e `kubectl` no master01, reiniciar kubelet.
6. Drenar worker01, atualizar `kubeadm`, `kubelet`, `kubectl`, reiniciar kubelet, uncordon.
7. Repetir ciclo para cada minor version ate a mais recente.

**6.2 — Upgrade simulado em ambiente de prova**
1. Identificar a versao mais recente disponivel: `apt-cache madison kubeadm`.
2. Executar `kubeadm upgrade plan` e registrar o output.
3. Cronometrar o ciclo completo de upgrade (meta: < 20 minutos por minor version).

---

## Checklist de Dominio

- [ ] Validar pre-requisitos de infraestrutura (swap, br_netfilter, containerd)
- [ ] Instalar cluster do zero com kubeadm
- [ ] Gerar token de join e adicionar worker
- [ ] Criar Role/ClusterRole e validar com `auth can-i`
- [ ] Fazer backup ETCD, deletar recursos, restaurar e validar
- [ ] Fazer upgrade de pelo menos 1 minor version (end-to-end)
- [ ] Cronometrar ciclo completo de upgrade (meta < 20 min)
