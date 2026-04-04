# Sub-tópico 03 — Manage Role Based Access Control (RBAC)

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — RBAC aparece em múltiplos domínios: cluster architecture, workloads e troubleshooting.

---

## Conceitos Fundamentais

### 3.1 O que é RBAC?

**Role-Based Access Control (RBAC)** é o mecanismo de autorização do Kubernetes. Ele controla **quem** pode fazer **o quê** em **quais recursos**.

Os quatro objetos principais:

| Objeto | Escopo | Propósito |
|--------|--------|-----------|
| `Role` | Namespace | Define permissões dentro de um namespace |
| `ClusterRole` | Cluster | Define permissões em todo o cluster (ou para recursos não-namespaciados) |
| `RoleBinding` | Namespace | Liga um Subject (usuário/grupo/SA) a uma Role (ou ClusterRole) dentro de um namespace |
| `ClusterRoleBinding` | Cluster | Liga um Subject a uma ClusterRole em todo o cluster |

### 3.2 Subjects (Sujeitos)

Um Subject é quem recebe as permissões:

```yaml
subjects:
- kind: User             # usuário autenticado (certificado, OIDC, etc.)
  name: "dev-user"
  apiGroup: rbac.authorization.k8s.io

- kind: Group            # grupo de usuários
  name: "developers"
  apiGroup: rbac.authorization.k8s.io

- kind: ServiceAccount   # identidade para pods/workloads
  name: "app-sa"
  namespace: "production"
```

### 3.3 Verbos (Ações)

Os verbos mapeiam para operações HTTP:

| Verbo | Ação |
|-------|------|
| `get` | Ler um recurso específico |
| `list` | Listar recursos |
| `watch` | Observar mudanças em tempo real |
| `create` | Criar recursos |
| `update` | Atualizar recursos existentes |
| `patch` | Atualizar parcialmente um recurso |
| `delete` | Remover um recurso |
| `deletecollection` | Remover múltiplos recursos |

### 3.4 Hierarquia de Escopo

```
ClusterRole ─────────────── ClusterRoleBinding ──► Subject (cluster-wide)
                 └───────── RoleBinding          ──► Subject (dentro de 1 namespace)

Role ────────────────────── RoleBinding          ──► Subject (dentro de 1 namespace)
```

> **Ponto crítico:** Uma `ClusterRole` pode ser referenciada por um `RoleBinding` — nesse caso, as permissões da ClusterRole são aplicadas **apenas no namespace** do RoleBinding.

---

## 4. Role e RoleBinding (Escopo de Namespace)

### 4.1 Criar Role imperativa

```bash
# Criar Role que permite get/list/watch em pods e services
kubectl create role app-role \
  --verb=get,list,watch \
  --resource=pods,services \
  --namespace=rbac-lab
```

### 4.2 Role em YAML

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: rbac-lab
rules:
- apiGroups: [""]          # "" = core API group (pods, services, configmaps, etc.)
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]      # apps group (deployments, replicasets, etc.)
  resources: ["deployments"]
  verbs: ["get", "list"]
```

### 4.3 ServiceAccount

```bash
# Criar ServiceAccount
kubectl create serviceaccount app-sa --namespace=rbac-lab
```

```yaml
# YAML equivalente
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: rbac-lab
```

### 4.4 RoleBinding

```bash
# Criar RoleBinding ligando app-sa à app-role
kubectl create rolebinding app-rb \
  --role=app-role \
  --serviceaccount=rbac-lab:app-sa \
  --namespace=rbac-lab
```

```yaml
# YAML equivalente
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rb
  namespace: rbac-lab
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-lab
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

---

## 5. ClusterRole e ClusterRoleBinding (Escopo de Cluster)

### 5.1 Criar ClusterRole imperativa

```bash
kubectl create clusterrole readonly-nodes \
  --verb=get,list,watch \
  --resource=nodes
```

### 5.2 ClusterRole em YAML

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-nodes
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

### 5.3 ClusterRoleBinding

```bash
kubectl create clusterrolebinding dev-user-readonly-nodes \
  --clusterrole=readonly-nodes \
  --user=dev-user
```

```yaml
# YAML equivalente
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dev-user-readonly-nodes
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: readonly-nodes
  apiGroup: rbac.authorization.k8s.io
```

---

## 6. Verificação de Permissões com `kubectl auth can-i`

### 6.1 Verificar permissão de um usuário

```bash
# Como o usuário atual
kubectl auth can-i list pods

# Como outro usuário (impersonação)
kubectl auth can-i list pods --as=dev-user

# Como ServiceAccount
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab

# Verificar permissão em namespace específico
kubectl auth can-i delete deployments --as=dev-user -n production
```

### 6.2 Listar todas as permissões de um subject

```bash
kubectl auth can-i --list --as=dev-user
kubectl auth can-i --list --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
```

---

## 7. API Groups — Como Descobrir o Correto

Um erro comum em RBAC é usar o `apiGroup` errado. Para descobrir:

```bash
# Listar todos os recursos e seus API groups
kubectl api-resources -o wide

# Exemplos:
# pods      → apiGroups: [""]          (core group, string vazia)
# deployments → apiGroups: ["apps"]
# ingresses   → apiGroups: ["networking.k8s.io"]
# roles       → apiGroups: ["rbac.authorization.k8s.io"]
```

---

## 8. Exercícios Práticos GUIADOS

### Básico

**Ex 3.1 — Criar ServiceAccount + Role + RoleBinding**
Neste exercício, daremos permissão de leitura de pods para uma ServiceAccount específica.

```bash
# 1. Criar namespace e ServiceAccount
kubectl create namespace rbac-lab
kubectl create serviceaccount app-sa -n rbac-lab

# 2. Criar a Role (permissão) no mesmo namespace
kubectl create role app-role --verb=get,list,watch --resource=pods,services -n rbac-lab

# 3. Criar o RoleBinding (ligando a conta à permissão)
kubectl create rolebinding app-rb --role=app-role --serviceaccount=rbac-lab:app-sa -n rbac-lab

# 4. Validar permissão concedida (esperado: yes)
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab

# 5. Validar permissão negada (esperado: no)
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab
```

**Ex 3.2 — ClusterRole para acesso somente-leitura a nodes**
Objetos de cluster (como nodes) exigem ClusterRoles.

```bash
# 1. Criar ClusterRole
kubectl create clusterrole readonly-nodes --verb=get,list,watch --resource=nodes

# 2. Criar ClusterRoleBinding para um usuário fictício
kubectl create clusterrolebinding dev-user-readonly-nodes --clusterrole=readonly-nodes --user=dev-user

# 3. Validar acessos no nível do cluster
kubectl auth can-i list nodes --as=dev-user   # esperado: yes
kubectl auth can-i delete nodes --as=dev-user # esperado: no
```

### Intermediário

**Ex 3.3 — Usar ClusterRole com RoleBinding (Reuso de permissão)**
Podemos usar uma `ClusterRole` genérica, mas restringi-la a apenas um namespace usando um `RoleBinding` comum.

```bash
# 1. Criar namespace de trabalho e a ClusterRole genérica
kubectl create namespace production
kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods

# 2. Criar RoleBinding (Atenção: NÃO é ClusterRoleBinding)
kubectl create rolebinding dev-user-prod-reader \
  --clusterrole=pod-reader \
  --user=dev-user \
  --namespace=production

# 3. Verificar que o usuário só tem acesso no namespace production
kubectl auth can-i list pods --as=dev-user -n production   # esperado: yes
kubectl auth can-i list pods --as=dev-user -n default      # esperado: no
```

### Avançado

**Ex 3.4 — Diagnosticar e corrigir RBAC quebrado em um Pod**
Vamos simular uma aplicação que tenta ler a API do Kubernetes mas é bloqueada porque está usando a ServiceAccount 'default' sem permissões.

```bash
# 1. Criar ServiceAccount 
kubectl create serviceaccount api-client

# 2. Implantar um pod que fica em loop tentando listar pods
kubectl create deployment rbac-test --image=bitnami/kubectl \
  -- sh -c "while true; do kubectl get pods; sleep 5; done"

# 3. Atribuir a ServiceAccount ao Deployment
kubectl set serviceaccount deployment rbac-test api-client

# 4. Verificar os logs (mostrarão erro 403 Forbidden)
# Aguarde alguns segundos para o pod subir antes de checar
kubectl logs deploy/rbac-test

# 5. Corrigir o problema dando a permissão necessária
kubectl create role list-pods --verb=get,list --resource=pods
kubectl create rolebinding api-client-rb --role=list-pods --serviceaccount=default:api-client

# 6. Confirmar que o erro desaparece dos logs (retornará a lista vazia ou os pods)
kubectl logs deploy/rbac-test --tail=10
```

---

## Armadilhas Comuns (Gotchas)

| Erro | Causa | Solução |
|------|-------|---------|
| `403 Forbidden` mesmo com Role criada | `RoleBinding` apontando para SA errada ou namespace errado | Verificar `subjects.namespace` no RoleBinding |
| `apiGroups: [""]` vs `apiGroups: ["apps"]` | Recurso não existe no group especificado | Usar `kubectl api-resources` para confirmar o grupo |
| ClusterRoleBinding com ServiceAccount sem namespace | Campo `namespace` obrigatório em SA dentro de ClusterRoleBinding | Adicionar `namespace` ao subject do tipo ServiceAccount |
| Role funciona mas pod ainda recebe 403 | Pod usa a SA `default`, não a SA criada | Especificar `serviceAccountName` no spec do Pod/Deployment |

---

## Dicas de Prova CKA

- **Prefira criar por YAML** para ter rastreabilidade e poder corrigir erros.
- Sempre use `kubectl auth can-i` para **validar antes e depois** de criar bindings.
- Em prova, o `--as` flag é seu melhor aliado para testar sem precisar trocar de contexto.
- Se um pod precisa de permissões, verifique qual SA ele usa: `kubectl get pod <nome> -o yaml | grep serviceAccountName`.
- Use `kubectl create role --dry-run=client -o yaml` para gerar o YAML base rapidamente.
