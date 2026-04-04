# Sub-tópico 01 — Deployments, Rolling Updates e Rollbacks

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — cobre o primitivo principal para rodar workloads em produção.

---

## Conceitos Fundamentais

### A Hierarquia: Deployment → ReplicaSet → Pod

O `Deployment` não cria pods diretamente. Ele cria um `ReplicaSet`, que é o responsável por manter o número de réplicas declarado.

```
Deployment  ──cria──►  ReplicaSet (v1, replicas=3)  ──cria──►  Pod A
                                                               Pod B
                                                               Pod C
```

Quando um update é feito, o Deployment cria um **novo** ReplicaSet e vai trocando os pods gradualmente. Os ReplicaSets antigos são mantidos para permitir rollback.

> **Regra prática:** Nunca edite diretamente um `ReplicaSet`. Ele é gerenciado pelo Deployment.

### Estratégias de Atualização

**RollingUpdate (padrão)** — substitui pods gradualmente:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 100%       # pods extras acima do replicas durante o update
    maxUnavailable: 0%   # pods que podem ficar indisponíveis
```

**Recreate** — termina todos os pods antes de criar os novos (downtime intencional):

```yaml
strategy:
  type: Recreate
```

Use `Recreate` quando a aplicação não suporta múltiplas versões simultâneas — ex: volume `ReadWriteOnce` ou porta exclusiva no host.

---

## Manifestos de Referência

### deploy.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy
spec:
  replicas: 5
  selector:
    matchLabels:
      app: deploy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 0%
  template:
    metadata:
      labels:
        app: deploy
    spec:
      containers:
      - image: httpd:latest
        name: httpd
```

### replicaset.yaml (referência — não gerenciar diretamente)

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: primeiro-replicaset
spec:
  replicas: 3
  selector:
    matchLabels:
      app: primeiro-replicaset
  template:
    metadata:
      labels:
        app: primeiro-replicaset
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        env:
        - name: POD_COLOR
          value: blue
```

---

## Comandos Essenciais (Prova)

```bash
# Criar Deployment
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3

# Gerar YAML sem aplicar
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3 \
  --dry-run=client -o yaml > deploy.yaml

# Atualizar imagem
kubectl set image deployment/nginx-deploy nginx-deploy=nginx:1.25

# Acompanhar rollout
kubectl rollout status deployment/nginx-deploy

# Histórico de revisões
kubectl rollout history deployment/nginx-deploy
kubectl rollout history deployment/nginx-deploy --revision=2

# Anotar causa da mudança (substitui o --record deprecado)
kubectl annotate deployment/nginx-deploy kubernetes.io/change-cause="upgrade para nginx 1.25"

# Rollback
kubectl rollout undo deployment/nginx-deploy
kubectl rollout undo deployment/nginx-deploy --to-revision=1

# Pausar e retomar rollout
kubectl rollout pause deployment/nginx-deploy
kubectl rollout resume deployment/nginx-deploy

# Escalar
kubectl scale deployment/nginx-deploy --replicas=5
```

---

## Exercícios

### 1.1 — Rolling update com observação do comportamento

1. Criar Deployment com `nginx:1.21` e `replicas: 3`:
   ```bash
   kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3
   ```
2. Em outro terminal, observar em tempo real:
   ```bash
   kubectl get pods -w
   ```
3. Atualizar a imagem:
   ```bash
   kubectl set image deployment/nginx-deploy nginx-deploy=nginx:1.25
   ```
4. Verificar histórico e anotar:
   ```bash
   kubectl rollout history deployment/nginx-deploy
   kubectl annotate deployment/nginx-deploy kubernetes.io/change-cause="upgrade para 1.25" --overwrite
   ```
5. Fazer rollback:
   ```bash
   kubectl rollout undo deployment/nginx-deploy
   ```
6. Confirmar que os pods retornaram para `nginx:1.21`:
   ```bash
   kubectl describe pods -l app=nginx-deploy | grep Image:
   ```

### 1.2 — Configurar maxSurge e maxUnavailable

1. Editar o Deployment: `kubectl edit deployment/nginx-deploy`
2. Testar com `maxSurge: 1` / `maxUnavailable: 0` — nunca cai abaixo de 3 pods disponíveis.
3. Testar com `maxSurge: 0` / `maxUnavailable: 1` — derruba 1 antes de subir o substituto.
4. Comparar o número de pods durante o rollout em cada caso.

### 1.3 — Estratégia Recreate

1. Criar Deployment com `strategy.type: Recreate`.
2. Atualizar a imagem e observar que **todos** os pods antigos terminam antes dos novos subirem.
3. Identificar a janela de downtime no `kubectl get pods -w`.

### 1.4 — Rollback para revisão específica

1. Fazer 3 updates consecutivos (`1.21` → `1.22` → `1.23` → `1.24`).
2. Listar o histórico: `kubectl rollout history deployment/nginx-deploy`
3. Fazer rollback direto para a revisão 1:
   ```bash
   kubectl rollout undo deployment/nginx-deploy --to-revision=1
   ```

---

## Pontos Críticos para a Prova

| Situação | O que lembrar |
|----------|--------------|
| Rollout travado | Pod pode estar em `ImagePullBackOff` — `kubectl describe pod` |
| `--record` gera aviso | Deprecado — usar `kubectl annotate` com `kubernetes.io/change-cause` |
| Campo imutável do pod | Use `kubectl rollout restart deployment/<nome>` para recrear |
| Deployment não avança | Verifique `readinessProbe` — se falhar, o rollout para |

---

## Arquivos desta pasta

| Arquivo | Descrição |
|---------|-----------|
| `deploy.yaml` | Deployment com RollingUpdate praticado |
| `replicaset.yaml` | ReplicaSet standalone de referência |
