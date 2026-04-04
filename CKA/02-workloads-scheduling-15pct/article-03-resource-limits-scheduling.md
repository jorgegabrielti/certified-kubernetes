# Resource Limits e Scheduling no Kubernetes

> **Série:** Kubernetes Descomplicado — Guia Prático para a CKA  
> **Domínio:** Workloads and Scheduling (15% do exame)  
> **Cobre:** Sub-tópico 5 — Understand how resource limits can affect Pod scheduling

---

## Como o Scheduler Decide Onde Colocar um Pod

O `kube-scheduler` percorre todos os nodes disponíveis e filtra os que **não atendem** aos requisitos do pod. O critério principal de filtragem são os `requests` de recursos:

```
Pod pede: cpu=500m, memory=256Mi

Node A: 200m disponível  → FILTRADO (insuficiente)
Node B: 600m disponível  → ELEGÍVEL
Node C: 1000m disponível → ELEGÍVEL (preferido — mais folga)
```

Se nenhum node for elegível, o pod fica em estado `Pending` indefinidamente, com evento `Insufficient cpu` ou `Insufficient memory`.

---

## Requests vs Limits

| Campo | O que define | Comportamento ao ser excedido |
|-------|-------------|-------------------------------|
| `requests` | Garantia mínima reservada no node | Usado apenas para scheduling; o pod pode usar mais |
| `limits` | Teto máximo de consumo | CPU: throttled (reduzido, não mata o pod); Memory: OOMKilled (pod reinicia) |

**Regra de ouro:**
- Defina sempre `requests` — o scheduler precisa deles para decidir o node.
- Defina `limits` para proteger outros pods no mesmo node.
- `requests` ≤ `limits`. Se `requests` for maior, a criação do pod é rejeitada.

```yaml
resources:
  requests:
    cpu: "100m"       # 0.1 vCPU garantido
    memory: "64Mi"
  limits:
    cpu: "200m"       # nunca usa mais que 0.2 vCPU (throttle)
    memory: "128Mi"   # se ultrapassar → OOMKilled
```

### Por que CPU e Memory se comportam diferente?

- **CPU é compressível:** pode ser reduzida sem perder dados. O kernel simplesmente dá menos tempo de CPU ao processo — ele roda mais devagar, mas não morre.
- **Memory é incompressível:** não dá para "reduzir" memória em uso sem matar o processo. Quando um container excede o `limit` de memória, o kernel envia `SIGKILL` (OOM Killer), e o Kubernetes reinicia o container.

---

## LimitRange

Aplicado no nível de **namespace**, define:
- Valores **padrão** (`default`) aplicados a pods sem `resources` especificado
- Valores **máximos** (`max`) — qualquer pod que solicite mais é rejeitado na admissão
- Valores **mínimos** (`min`) — qualquer pod que solicite menos é rejeitado

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

**Comportamento:**
- Pod criado sem `resources` → recebe os valores de `default` e `defaultRequest`
- Pod criado com `limits` acima do `max` → `LimitRange "default-limits": maximum cpu usage per Container is 500m`

> O `LimitRange` é aplicado no momento da criação do pod pelo **Admission Controller**. Pods existentes não são afetados quando o LimitRange é criado ou alterado.

---

## ResourceQuota

Limita o consumo **total** de recursos ou número de objetos em um namespace:

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
    services: "5"
```

**Quando ResourceQuota está ativo:**
- Todo pod **deve** ter `requests` e `limits` definidos — caso contrário, é rejeitado.
- Use `LimitRange` em conjunto para definir defaults e evitar rejeições.

```bash
# Ver estado atual da quota
kubectl describe resourcequota ns-quota -n limited-ns

# Output:
# Resource         Used  Hard
# --------         ----  ----
# limits.cpu       400m  4
# pods             4     10
# requests.cpu     200m  2
```

---

## Scheduling Manual — nodeSelector e nodeName

### nodeSelector

Agenda o pod apenas em nodes com determinado label:

```yaml
spec:
  nodeSelector:
    kubernetes.io/hostname: kind-worker    # label padrão do node
    disk: ssd                              # label customizado
  containers:
  - name: app
    image: nginx
```

Adicionar label a um node:
```bash
kubectl label node kind-worker disk=ssd
```

Se nenhum node tiver o label, o pod fica `Pending`.

### nodeName

Bypassa o scheduler completamente — o pod vai diretamente para o node especificado:

```yaml
spec:
  nodeName: kind-worker
  containers:
  - name: app
    image: nginx
```

> **Quando usar `nodeName`:** Apenas para diagnóstico ou quando você precisa testar algo em um node específico. Em produção, prefira `nodeSelector` ou `nodeAffinity`.

---

## Taints e Tolerations (contexto de scheduling)

Taints **repelem** pods de um node. Tolerations permitem que pods específicos ignorem a repulsa.

```bash
# Adicionar taint
kubectl taint node kind-worker dedicated=gpu:NoSchedule

# O pod só vai para esse node se tiver a toleration:
```

```yaml
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
```

**Efeitos de taint:**

| Efeito | Comportamento |
|--------|--------------|
| `NoSchedule` | Pods novos sem toleration não são agendados no node |
| `PreferNoSchedule` | Scheduler tenta evitar, mas pode agendar se não houver alternativa |
| `NoExecute` | Expulsa pods **já rodando** sem toleration (com `tolerationSeconds` opcional) |

> Os control plane nodes têm o taint `node-role.kubernetes.io/control-plane:NoSchedule` — por isso pods de usuário não vão para o master por padrão.

---

## Diagnóstico de Pod Pending

```bash
# 1. Ver o status do pod
kubectl get pod <pod> -o wide

# 2. Ver os eventos — causa real estará aqui
kubectl describe pod <pod> | grep -A 20 Events

# Mensagens comuns:
# 0/2 nodes are available: insufficient cpu
# 0/2 nodes are available: node(s) had untolerated taint

# 3. Ver recursos disponíveis por node
kubectl describe nodes | grep -E "Name:|Allocated|cpu|memory" -A 3

# 4. Ver requests/limits dos pods existentes
kubectl top pod --all-namespaces   # requer metrics-server
```

---

## Exercícios

### 5.1 — Pod com requests e limits

1. Criar pod com requests e limits explícitos:
   ```yaml
   resources:
     requests:
       cpu: "100m"
       memory: "64Mi"
     limits:
       cpu: "200m"
       memory: "128Mi"
   ```
2. Verificar agendamento:
   ```bash
   kubectl describe pod <pod> | grep -A 5 Requests
   ```
3. Criar pod com requests maiores que qualquer node:
   ```yaml
   resources:
     requests:
       cpu: "100"     # 100 vCPUs
       memory: "100Gi"
   ```
4. Observar o pod ficar `Pending` e ler o evento:
   ```bash
   kubectl describe pod <pod> | grep -A 5 Events
   ```

### 5.2 — LimitRange

1. Criar namespace:
   ```bash
   kubectl create namespace limited-ns
   ```
2. Aplicar LimitRange com default de `100m`/`128Mi` e max de `500m`/`512Mi`.
3. Criar pod **sem** especificar resources:
   ```bash
   kubectl run limited-pod --image=nginx -n limited-ns
   ```
4. Confirmar que as defaults foram aplicadas:
   ```bash
   kubectl describe pod limited-pod -n limited-ns | grep -A 5 Limits
   ```
5. Tentar criar pod com `limits.cpu: "2"` (acima do max) e observar rejeição.

### 5.3 — ResourceQuota

1. Criar `ResourceQuota` no namespace `limited-ns` com `pods: 3`.
2. Criar 3 pods e confirmar que todos sobem.
3. Tentar criar o 4o pod e observar o erro de quota:
   ```
   Error from server (Forbidden): exceeded quota: ns-quota, requested: pods=1, used: pods=3, limited: pods=3
   ```

### 5.4 — nodeSelector

1. Listar labels dos nodes:
   ```bash
   kubectl get nodes --show-labels
   ```
2. Adicionar label customizado:
   ```bash
   kubectl label node kind-worker tier=frontend
   ```
3. Criar pod com `nodeSelector: {tier: frontend}` e confirmar que foi para o node correto.
4. Remover o label e criar o pod novamente — observar que fica `Pending`.

---

## Referência Rápida

```bash
# Verificar recursos disponíveis por node
kubectl describe nodes | grep -A 5 "Allocated resources"

# Ver por que pod está Pending
kubectl describe pod <pod> | grep -A 10 Events

# Adicionar/remover label de node
kubectl label node <node> <chave>=<valor>
kubectl label node <node> <chave>-

# Adicionar/remover taint
kubectl taint node <node> <chave>=<valor>:<efeito>
kubectl taint node <node> <chave>-

# Ver LimitRange e ResourceQuota
kubectl get limitrange -n <ns>
kubectl describe resourcequota -n <ns>

# Testar se pod tem recursos suficientes no cluster
kubectl describe nodes | grep -E "(cpu|memory)" | grep -v "%" 
```
