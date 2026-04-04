# Deployments, Rolling Updates e Rollbacks no Kubernetes

> **Série:** Kubernetes Descomplicado — Guia Prático para a CKA  
> **Domínio:** Workloads and Scheduling (15% do exame)  
> **Cobre:** Sub-tópico 1 — Understand deployments and how to perform rolling updates and rollbacks

---

## Por que este artigo existe?

Na prova da CKA, você vai gerenciar Deployments sob pressão de tempo. A maioria dos erros não acontece no comando em si — acontece no entendimento de **o que está acontecendo** durante um rollout e no uso correto das flags.

Este artigo explica a hierarquia `Deployment → ReplicaSet → Pod`, as estratégias de atualização e os comandos de rollout que aparecem na prova.

---

## A Hierarquia: Deployment → ReplicaSet → Pod

Quando você cria um `Deployment`, ele não cria pods diretamente. Ele cria um `ReplicaSet`. O `ReplicaSet` é quem cria e mantém os pods.

```
Deployment  ──cria──►  ReplicaSet (v1, replicas=3)  ──cria──►  Pod A
                                                               Pod B
                                                               Pod C
```

Quando você faz um update, o Deployment cria um **novo** `ReplicaSet` e vai trocando os pods gradualmente:

```
Deployment  ──►  ReplicaSet (v1, replicas=3 → 0)   ──►  pods antigos terminam
            ──►  ReplicaSet (v2, replicas=0 → 3)   ──►  pods novos sobem
```

O Deployment guarda os ReplicaSets antigos — é por isso que o rollback funciona. Ele simplesmente pede ao ReplicaSet anterior que volte a ter réplicas.

> **Regra prática:** Nunca edite diretamente um `ReplicaSet`. Ele é gerenciado pelo Deployment e suas mudanças serão sobrescritas.

---

## Estratégias de Atualização

### RollingUpdate (padrão)

Substitui pods gradualmente. Os parâmetros que controlam o ritmo:

| Parâmetro | O que faz | Exemplo |
|-----------|----------|---------|
| `maxSurge` | Quantos pods extras podem existir acima do `replicas` | `1` ou `25%` |
| `maxUnavailable` | Quantos pods podem ficar indisponíveis simultaneamente | `1` ou `25%` |

**Configuração para zero downtime** (usada em produção):

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 100%       # pode dobrar a frota durante o update
    maxUnavailable: 0%   # nunca derruba pods antes de novos estarem prontos
```

**Configuração conservadora** (economiza recursos):

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1    # derruba 1 antes de subir o substituto
```

### Recreate

Termina **todos** os pods antes de criar os novos. Gera downtime intencional.

```yaml
strategy:
  type: Recreate
```

**Quando usar:** Aplicações que não suportam múltiplas versões simultâneas — por exemplo, quando dois pods tentariam escrever no mesmo volume exclusivo (`ReadWriteOnce`) ou usar a mesma porta no host.

---

## Manifesto Completo

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  annotations:
    kubernetes.io/change-cause: "versao inicial nginx 1.21"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
```

---

## Comandos de Rollout — Referência Rápida

```bash
# --- CRIAR ---
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3

# Gerar YAML (sem aplicar) — útil na prova
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3 \
  --dry-run=client -o yaml > deploy.yaml

# --- ATUALIZAR ---
kubectl set image deployment/nginx-deploy nginx=nginx:1.25

# Atualizar via patch
kubectl patch deployment nginx-deploy -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.25"}]}}}}'

# --- ACOMPANHAR ---
kubectl rollout status deployment/nginx-deploy
kubectl get pods -w   # watch em tempo real

# --- HISTÓRICO ---
kubectl rollout history deployment/nginx-deploy
kubectl rollout history deployment/nginx-deploy --revision=2

# Anotar causa da mudança (substitui o --record deprecado)
kubectl annotate deployment/nginx-deploy kubernetes.io/change-cause="upgrade para 1.25"

# --- ROLLBACK ---
kubectl rollout undo deployment/nginx-deploy                   # volta 1 revisão
kubectl rollout undo deployment/nginx-deploy --to-revision=1   # revisão específica

# --- PAUSAR / RETOMAR ---
kubectl rollout pause deployment/nginx-deploy
# faça múltiplas mudanças sem disparar rollout
kubectl rollout resume deployment/nginx-deploy

# --- ESCALAR ---
kubectl scale deployment/nginx-deploy --replicas=5
```

---

## Exercícios

### 1.1 — Rolling update com observação do comportamento

1. Criar o Deployment com `nginx:1.21` e `replicas: 3`:
   ```bash
   kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3
   ```
2. Verificar que os 3 pods estão `Running`:
   ```bash
   kubectl get pods -l app=nginx-deploy
   ```
3. Atualizar a imagem:
   ```bash
   kubectl set image deployment/nginx-deploy nginx-deploy=nginx:1.25
   ```
4. Em outro terminal, observar em tempo real:
   ```bash
   kubectl get pods -w
   ```
5. Verificar histórico:
   ```bash
   kubectl rollout history deployment/nginx-deploy
   ```
6. Fazer rollback:
   ```bash
   kubectl rollout undo deployment/nginx-deploy
   ```
7. Confirmar que os pods retornaram para `nginx:1.21`:
   ```bash
   kubectl describe pods -l app=nginx-deploy | grep Image:
   ```

### 1.2 — Configurar maxSurge e maxUnavailable

1. Editar o Deployment criado acima:
   ```bash
   kubectl edit deployment/nginx-deploy
   ```
2. Alterar para `maxSurge: 1` e `maxUnavailable: 0`.
3. Realizar update e confirmar que nunca há menos de 3 pods disponíveis.
4. Testar com `maxSurge: 0` e `maxUnavailable: 1` e comparar.

### 1.3 — Estratégia Recreate

1. Criar novo Deployment com `Recreate`:
   ```bash
   kubectl create deployment recreate-deploy --image=nginx:1.21 --replicas=3 \
     --dry-run=client -o yaml \
     | kubectl patch -f - --type merge -p '{"spec":{"strategy":{"type":"Recreate"}}}' \
     --dry-run=client -o yaml \
     | kubectl apply -f -
   ```
   Ou editar o YAML manualmente e aplicar.
2. Atualizar a imagem e observar que **todos** os pods antigos terminam antes dos novos subirem.
3. Identificar o janela de downtime no output do `kubectl get pods -w`.

### 1.4 — Rollback para revisão específica

1. Fazer 3 updates consecutivos alterando a imagem (ex: `1.21` → `1.22` → `1.23` → `1.24`).
2. Anotar cada mudança:
   ```bash
   kubectl annotate deployment/nginx-deploy kubernetes.io/change-cause="upgrade para 1.22" --overwrite
   ```
3. Listar o histórico e identificar a revisão desejada.
4. Fazer rollback direto para a revisão 1:
   ```bash
   kubectl rollout undo deployment/nginx-deploy --to-revision=1
   ```

---

## Pontos Críticos para a Prova

| Situação | O que lembrar |
|----------|--------------|
| `kubectl rollout undo` falha | Verifique se o ReplicaSet antigo ainda existe: `kubectl get rs` |
| Rollout travado em `Waiting` | Pod pode estar em `ImagePullBackOff` — verifique com `kubectl describe pod` |
| `--record` gera aviso | Está deprecado; use `kubectl annotate` com `kubernetes.io/change-cause` |
| Precisa editar campo imutável do pod | Use `kubectl rollout restart deployment/<nome>` para recrear os pods |
| Deployment não avança | Verifique `readinessProbe` — se falhar, o rollout para e não avança |
