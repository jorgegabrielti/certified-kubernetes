# Sub-tópico 05 — Resource Limits e Scheduling

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — requests/limits afetam scheduling diretamente; nodeSelector e taints são cobrados em troubleshooting.

---

## Conceitos Fundamentais

### Como o Scheduler Decide

O `kube-scheduler` filtra nodes que **não atendem** aos `requests` do pod:

```
Pod pede: cpu=500m, memory=256Mi

Node A: 200m disponível  → FILTRADO (insuficiente)
Node B: 600m disponível  → ELEGÍVEL
Node C: 1000m disponível → ELEGÍVEL (preferido)
```

Se nenhum node for elegível → pod fica `Pending` com evento `Insufficient cpu/memory`.

### Requests vs Limits

| Campo | O que define | Comportamento ao exceder |
|-------|-------------|--------------------------|
| `requests` | Garantia mínima reservada no node (usado pelo scheduler) | — |
| `limits.cpu` | Teto de CPU | Throttle — processo roda mais devagar, não morre |
| `limits.memory` | Teto de memória | OOMKill — `SIGKILL`, pod reinicia |

```yaml
resources:
  requests:
    cpu: "100m"      # 0.1 vCPU garantido para scheduling
    memory: "64Mi"
  limits:
    cpu: "200m"      # nunca usa mais que 0.2 vCPU (throttle)
    memory: "128Mi"  # se ultrapassar → OOMKilled
```

**Regra:** `requests` ≤ `limits`. Se `requests` > `limits`, a criação é rejeitada.

---

## LimitRange

Define **defaults** e **tetos** por namespace — aplicado pelo Admission Controller na criação do pod.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: limited-ns
spec:
  limits:
  - type: Container
    default:
      cpu: "100m"
      memory: "128Mi"
    defaultRequest:
      cpu: "50m"
      memory: "64Mi"
    max:
      cpu: "500m"
      memory: "512Mi"
    min:
      cpu: "10m"
      memory: "16Mi"
```

- Pod sem `resources` → recebe os valores de `default` e `defaultRequest`
- Pod com `limits` acima de `max` → rejeitado com erro de admissão
- LimitRange não afeta pods **já existentes**

---

## ResourceQuota

Limita o total de recursos ou objetos em um namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: limited-ns
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
    configmaps: "20"
    secrets: "10"
```

> **Atenção:** Quando `ResourceQuota` está ativo no namespace, todo pod **deve** ter `requests` e `limits` definidos — ou seja, use `LimitRange` junto para evitar rejeições de pods sem resources.

---

## Scheduling Manual

### nodeSelector

```yaml
spec:
  nodeSelector:
    tier: frontend           # label customizado
    kubernetes.io/os: linux  # label de sistema
```

```bash
# Adicionar label ao node
kubectl label node kind-worker tier=frontend

# Remover label
kubectl label node kind-worker tier-
```

### nodeName

Bypassa o scheduler completamente:

```yaml
spec:
  nodeName: kind-worker
```

### Taints e Tolerations

**Taints** repelem pods de um node. **Tolerations** permitem que pods específicos ignorem a repulsa.

```bash
# Adicionar taint
kubectl taint node kind-worker dedicated=gpu:NoSchedule

# Remover taint
kubectl taint node kind-worker dedicated=gpu:NoSchedule-
```

```yaml
# Toleration no pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
```

| Efeito | Comportamento |
|--------|--------------|
| `NoSchedule` | Novos pods sem toleration não são agendados |
| `PreferNoSchedule` | Scheduler tenta evitar, mas pode agendar |
| `NoExecute` | Expulsa pods **já rodando** sem toleration |

> O control plane tem o taint `node-role.kubernetes.io/control-plane:NoSchedule` — por isso os pods de usuário não vão para o master por padrão.

---

## Diagnóstico de Pod Pending

```bash
# 1. Status geral
kubectl get pod <pod> -o wide

# 2. Eventos — causa real
kubectl describe pod <pod> | grep -A 20 Events
# Mensagens comuns:
# 0/2 nodes are available: insufficient cpu
# 0/2 nodes are available: node(s) had untolerated taint

# 3. Recursos por node
kubectl describe nodes | grep -E "Name:|Allocated resources" -A 5

# 4. Ver requests/limits em uso
kubectl top pod --all-namespaces   # requer metrics-server
```

---

## Comandos Essenciais (Prova)

```bash
# Recursos disponíveis por node
kubectl describe nodes | grep -A 5 "Allocated resources"

# Labels dos nodes
kubectl get nodes --show-labels
kubectl label node <node> <chave>=<valor>

# Taints dos nodes
kubectl describe node <node> | grep Taints

# LimitRange e ResourceQuota
kubectl get limitrange -n <ns>
kubectl describe resourcequota -n <ns>

# Agendar pod em node específico via overrides
kubectl run pod-node --image=nginx \
  --overrides='{"spec":{"nodeName":"kind-worker"}}'
```

---

## Exercícios

### 5.1 — Pod com requests e limits

1. Criar pod com requests e limits explícitos e verificar agendamento:
   ```bash
   kubectl describe pod <pod> | grep -A 5 Requests
   ```
2. Criar pod com requests impossíveis (`cpu: "100"`) e observar `Pending`:
   ```bash
   kubectl describe pod <pod> | grep -A 5 Events
   ```

### 5.2 — LimitRange

1. Criar namespace: `kubectl create namespace limited-ns`
2. Aplicar LimitRange com default `100m`/`128Mi` e max `500m`/`512Mi`.
3. Criar pod **sem** resources e confirmar que as defaults foram aplicadas.
4. Tentar criar pod com `limits.cpu: "2"` e observar rejeição.

### 5.3 — ResourceQuota

1. Criar quota com `pods: 3` no namespace `limited-ns`.
2. Criar 3 pods — todos devem subir.
3. Criar o 4o pod e observar:
   ```
   Error from server (Forbidden): exceeded quota: ns-quota, requested: pods=1, used: pods=3, limited: pods=3
   ```

### 5.4 — nodeSelector

1. Listar labels: `kubectl get nodes --show-labels`
2. Adicionar label: `kubectl label node kind-worker tier=frontend`
3. Criar pod com `nodeSelector: {tier: frontend}` e confirmar node correto.
4. Remover label e criar pod — deve ficar `Pending`.

### 5.5 — Taints e Tolerations

1. Adicionar taint: `kubectl taint node kind-worker dedicated=gpu:NoSchedule`
2. Criar pod sem toleration — deve ficar `Pending`.
3. Adicionar toleration ao pod e confirmar que é agendado.
4. Limpar taint: `kubectl taint node kind-worker dedicated=gpu:NoSchedule-`
