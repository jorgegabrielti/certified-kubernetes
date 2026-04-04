# Workloads and Scheduling — 15%

Referencia: [CKA Curriculum v1.35](../CKA_Curriculum_v1.35.pdf)

> Segundo dominio de conceitos mais praticados no dia a dia. Cobre desde primitivos basicos de execucao ate mecanismos de scheduling e configuracao de aplicacoes.

---

## Artigos

| Artigo | Conteudo |
|--------|----------|
| [article-01-deployments-rolling-updates.md](./article-01-deployments-rolling-updates.md) | Deployments, ReplicaSets, estrategias de rollout, rollback |
| [article-02-configmaps-secrets.md](./article-02-configmaps-secrets.md) | ConfigMaps e Secrets — env, envFrom, volumeMount |
| [article-03-resource-limits-scheduling.md](./article-03-resource-limits-scheduling.md) | Requests, Limits, LimitRange, ResourceQuota, nodeSelector |

---

## Sub-topicos

Ordem logica de estudo (fundamento → avancado):

| # | Topico | Peso estimado | Conteudo |
|---|--------|:-------------:|----------|
| 1 | Understand deployments and how to perform rolling update and rollbacks | **Alto** | [01-deployments-rolling-updates/](./01-deployments-rolling-updates/) |
| 2 | Use ConfigMaps and Secrets to configure applications | **Alto** | [02-configmaps-secrets/](./02-configmaps-secrets/) |
| 3 | Know how to scale applications | Medio | [03-scaling/](./03-scaling/) |
| 4 | Understand the primitives used to create robust, self-healing, application deployments | Medio | [04-self-healing-primitives/](./04-self-healing-primitives/) |
| 5 | Understand how resource limits can affect Pod scheduling | **Alto** | [05-resource-limits-scheduling/](./05-resource-limits-scheduling/) |
| 6 | Awareness of manifest management and common templating tools | Baixo | [06-manifest-management/](./06-manifest-management/) |

---

## 1. Deployments, Rolling Updates e Rollbacks

### Conceitos
- `Deployment` gerencia `ReplicaSets`; nunca edite o `ReplicaSet` diretamente
- `kubectl rollout status`, `kubectl rollout history`, `kubectl rollout undo`
- Estrategia `RollingUpdate` vs `Recreate`
- `maxSurge` — pods extras alem do desejado durante o update
- `maxUnavailable` — pods que podem ficar indisponiveis durante o update
- `--record` (deprecado) → use anotacao manual `kubernetes.io/change-cause`

### Manifesto de referencia (deploy.yaml)

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
      maxSurge: 100%        # dobra a frota durante o update — zero downtime
      maxUnavailable: 0%    # nunca reduz abaixo do desejado
  template:
    metadata:
      labels:
        app: deploy
    spec:
      containers:
      - image: httpd:latest
        name: httpd
```

### Comandos imperatives essenciais (prova)

```bash
# Criar deployment (imperativo)
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3

# Gerar YAML sem aplicar (dry-run)
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3 --dry-run=client -o yaml > deploy.yaml

# Atualizar imagem
kubectl set image deployment/nginx-deploy nginx=nginx:1.25

# Acompanhar rollout
kubectl rollout status deployment/nginx-deploy

# Historico
kubectl rollout history deployment/nginx-deploy

# Rollback para a versao anterior
kubectl rollout undo deployment/nginx-deploy

# Rollback para uma versao especifica
kubectl rollout undo deployment/nginx-deploy --to-revision=2

# Anotar causa da mudanca (substitui --record)
kubectl annotate deployment/nginx-deploy kubernetes.io/change-cause="upgrade para nginx 1.25"

# Pausar e retomar rollout
kubectl rollout pause deployment/nginx-deploy
kubectl rollout resume deployment/nginx-deploy
```

### Exercicios

**1.1 — Rolling update controlado**
1. Criar `Deployment` com `nginx:1.21` e `replicas: 3`.
2. Atualizar a imagem para `nginx:1.25`: `kubectl set image deployment/nginx-deploy nginx=nginx:1.25`.
3. Acompanhar: `kubectl rollout status deployment/nginx-deploy`.
4. Verificar historico: `kubectl rollout history deployment/nginx-deploy`.
5. Fazer rollback para a versao anterior: `kubectl rollout undo deployment/nginx-deploy`.
6. Confirmar que os pods voltaram para `nginx:1.21`.

**1.2 — Configurar estrategia de rollout**
1. Editar o `Deployment` para usar `maxSurge: 1` e `maxUnavailable: 0`.
2. Realizar novo update e observar que nunca ha pods indisponiveis durante o processo.
3. Testar com `maxSurge: 0` e `maxUnavailable: 1` e comparar o comportamento.

**1.3 — Estrategia Recreate**
1. Criar novo `Deployment` com estrategia `Recreate`.
2. Atualizar a imagem e observar que todos os pods antigos terminam antes dos novos subirem.
3. Identificar em qual cenario `Recreate` e apropriado (ex: conflito de porta, volume exclusivo).

---

## 2. ConfigMaps e Secrets

### Conceitos
- `ConfigMap` — configuracao nao-sensivel injetada via `env`, `envFrom` ou `volumeMount`
- `Secret` — configuracao sensivel (base64 encoded, nao criptografada por padrao)
- `secretKeyRef`, `configMapKeyRef` — injecao de chaves especificas
- `envFrom` — injecao de todo o ConfigMap/Secret como variaveis de ambiente
- Montagem como volume: mudancas no ConfigMap propagam automaticamente (< 60s)
- Montagem como `env`: nao propaga — requer reinicio do pod

### Manifesto de referencia — ConfigMap (configMap.yaml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: primeiro-configmap
data:
  key1: "value1"
  key2: "value2"
  key.parameters: |
    chave3: "valor3"
```

### Manifesto de referencia — Pod com ConfigMap (pod3.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-completo
spec:
  volumes:
  - name: configmap
    configMap:
      name: primeiro-configmap
      items:
      - key: key.parameters
        path: key.parameters   # obrigatorio quando 'key' e especificado
  containers:
  - name: configmap-container
    image: alpine:latest
    command: ["sleep", "8000"]
    volumeMounts:
    - name: configmap
      mountPath: /etc/podconfig
      readOnly: true
    env:
    - name: ENV_KEY1
      value: "value1"
    - name: ENV_KEY2
      valueFrom:
        configMapKeyRef:
          name: primeiro-configmap
          key: key1
    - name: ENV_KEY3
      valueFrom:
        configMapKeyRef:
          name: primeiro-configmap
          key: key2
```

### Armadilhas comuns (vistas na pratica)

| Erro | Causa | Correcao |
|------|-------|----------|
| `unknown field "spec.containers[0].commands"` | Campo errado: `commands` nao existe | Usar `command` (singular) |
| `spec.volumes[0].configMap.items[0].path: Required value` | Quando `key` e definido, `path` e obrigatorio | Adicionar `path: <nome-do-arquivo>` |
| `spec.containers[0].env[N].name: Required value` | Campo `name:` vazio no env | Preencher o nome da variavel |
| `couldn't find key X in ConfigMap` | Chave nao existe no ConfigMap | Verificar com `kubectl get cm <nome> -o yaml` |
| Pod nao recria ao `kubectl apply` | apply nao recria pods — apenas atualiza o manifesto | `kubectl delete pod <nome>` e depois `kubectl apply` ou `kubectl replace --force` |

### Comandos essenciais

```bash
# Criar ConfigMap imperativo
kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=APP_PORT=8080

# Criar ConfigMap a partir de arquivo
kubectl create configmap nginx-config --from-file=nginx.conf

# Inspecionar chaves de um ConfigMap
kubectl get configmap primeiro-configmap -o yaml

# Criar Secret
kubectl create secret generic app-secret --from-literal=DB_PASSWORD=senha123

# Decodificar valor de Secret
kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### Exercicios

**2.1 — ConfigMap como variaveis de ambiente**
1. Criar `ConfigMap` `app-config` com chave `APP_ENV=production` e `APP_PORT=8080`.
2. Criar pod que injeta todo o ConfigMap via `envFrom`.
3. Validar: `kubectl exec <pod> -- env | grep APP_`.

**2.2 — ConfigMap como arquivo montado**
1. Criar `ConfigMap` com conteudo de um arquivo de configuracao (ex: `nginx.conf`).
2. Montar o ConfigMap como volume no path `/etc/nginx/conf.d/`.
3. Validar que o arquivo esta acessivel dentro do container.

**2.3 — Secret como variavel de ambiente**
1. Criar `Secret` `app-secret` do tipo `Opaque` com chave `DB_PASSWORD`.
2. Criar pod que injeta apenas essa chave via `secretKeyRef`.
3. Validar: `kubectl exec <pod> -- printenv DB_PASSWORD`.
4. Identificar o valor original: `kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d`.

**2.4 — Atualizar ConfigMap e validar propagacao**
1. Montar um `ConfigMap` como volume num pod.
2. Atualizar o valor no ConfigMap: `kubectl edit configmap app-config`.
3. Aguardar propagacao (geralmente < 60s) e verificar dentro do pod.
4. Comparar comportamento com variavel de ambiente (nao propaga sem reinicio do pod).

---

## 3. Scaling

### Conceitos
- `kubectl scale` — escala manual imediata
- `HorizontalPodAutoscaler (HPA)` — escala automatica por CPU/memoria
- `replicas` no manifesto do `Deployment`
- Impacto de `PodDisruptionBudget` no scale-down

### Exercicios

**3.1 — Scale manual**
1. Criar `Deployment` com `replicas: 2`.
2. Escalar para 5: `kubectl scale deployment/my-app --replicas=5`.
3. Observar criacao dos pods: `kubectl get pods -w`.
4. Reduzir para 1 e observar terminacao.

**3.2 — HorizontalPodAutoscaler**
> Requer metrics-server instalado no lab.
1. Instalar metrics-server: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`.
2. Criar HPA: `kubectl autoscale deployment my-app --cpu-percent=50 --min=2 --max=10`.
3. Gerar carga no pod para disparar scale-up.
4. Observar: `kubectl get hpa -w`.

---

## 4. Primitivos para Aplicacoes Resilientes

### Conceitos
- `livenessProbe`, `readinessProbe`, `startupProbe`
- `restartPolicy`: `Always`, `OnFailure`, `Never`
- `DaemonSet` — um pod por node
- `StatefulSet` — identidade estavel (hostname, PVC por pod)
- `Job` e `CronJob` — execucao finita e agendada
- `InitContainers` — inicializacao sequencial antes do container principal

### Exercicios

**4.1 — Probes**
1. Criar `Deployment` com `readinessProbe` HTTP na rota `/healthz`.
2. Fazer a probe falhar (alterar a rota para `/fail`) e observar que o pod para de receber trafego mas nao reinicia.
3. Criar `livenessProbe` na mesma rota e observar que agora o pod reinicia ao falhar.
4. Adicionar `startupProbe` com `failureThreshold: 30` para uma aplicacao de inicializacao lenta.

**4.2 — DaemonSet**
1. Criar `DaemonSet` com `busybox` que executa `sleep 3600`.
2. Confirmar que ha exatamente 1 pod por node.
3. Adicionar um novo node e validar que o DaemonSet escalou automaticamente.

**4.3 — Job e CronJob**
1. Criar `Job` que executa `perl -Mbignum=bpi -wle 'print bpi(2000)'`.
2. Configurar `completions: 3` e `parallelism: 2`.
3. Criar `CronJob` que executa `date` a cada minuto.
4. Apos 3 execucoes, suspender o CronJob: `kubectl patch cronjob my-cron -p '{"spec":{"suspend":true}}'`.

**4.4 — InitContainer**
1. Criar pod com `initContainer` que aguarda um servico existir (usando `nslookup`).
2. Verificar que o pod fica em `Init:0/1` ate o servico ser criado.
3. Criar o servico e confirmar que o pod progride.

---

## 5. Resource Limits e Scheduling

### Conceitos
- `requests` — quantidade garantida; usada pelo scheduler para decidir em qual node colocar o pod
- `limits` — teto de consumo (CPU: throttle; Memory: OOMKill → pod reinicia)
- `LimitRange` — define defaults e maximos de namespace (aplicado na criacao do pod)
- `ResourceQuota` — teto total de recursos ou objetos por namespace
- `nodeSelector` — agendamento por label de node
- `nodeName` — agendamento direto, bypassa o scheduler

### Pontos de atencao para a prova

| Situacao | Comportamento |
|----------|---------------|
| Pod sem `requests` em namespace com `LimitRange` | Recebe os defaults do LimitRange |
| Pod com `requests` maior que qualquer node | Fica `Pending` com evento `Insufficient cpu/memory` |
| Pod excede `memory limit` | OOMKilled — reinicia automaticamente |
| Pod excede `cpu limit` | CPU throttled — nao reinicia |
| Namespace com `ResourceQuota` atingido | Erro de admissao na criacao do proximo recurso |

### Comandos essenciais

```bash
# Verificar recursos por node
kubectl describe nodes | grep -A 5 "Allocated resources"

# Ver por que um pod esta Pending
kubectl describe pod <pod> | grep -A 10 Events

# Criar LimitRange
kubectl apply -f limitrange.yaml

# Ver quotas de namespace
kubectl describe resourcequota -n <namespace>

# Agendar pod em node especifico
kubectl run pod-node --image=nginx --overrides='{"spec":{"nodeName":"kind-worker"}}'
```

### Exercicios

**5.1 — Pod com requests e limits**
1. Criar pod com:
   ```yaml
   resources:
     requests:
       cpu: "100m"
       memory: "64Mi"
     limits:
       cpu: "200m"
       memory: "128Mi"
   ```
2. Verificar agendamento: `kubectl describe pod <pod> | grep -A 5 Requests`.
3. Criar pod com requests maiores que qualquer node disponivel e observar `Pending` + evento `Insufficient cpu`.

**5.2 — LimitRange**
1. Criar namespace `limited-ns`.
2. Criar `LimitRange` definindo default de `100m`/`128Mi` e max de `500m`/`512Mi`.
3. Criar pod sem especificar resources e confirmar que as defaults foram aplicadas.
4. Tentar criar pod com limits acima do maximo e observar o erro de admissao.

**5.3 — ResourceQuota**
1. Criar `ResourceQuota` no namespace `limited-ns` com `pods: 3`.
2. Criar 3 pods e confirmar que todos sobem.
3. Tentar criar o 4o pod e observar o erro de quota.

---

## 6. Gestao de Manifestos

### Conceitos
- `kubectl apply` (declarativo) vs `kubectl create` (imperativo)
- `Kustomize` — overlays sem templates
- `Helm` — package manager com templating
- `kubectl kustomize` / `kustomize build`

### Exercicios

**6.1 — Kustomize basico**
1. Criar estrutura `base/` com `Deployment` e `Service`.
2. Criar `overlays/staging/` com `kustomization.yaml` que modifica o numero de replicas.
3. Aplicar: `kubectl apply -k overlays/staging/`.

**6.2 — Helm basico**
1. Instalar Helm: `https://helm.sh/docs/intro/install/`.
2. Adicionar repositorio: `helm repo add bitnami https://charts.bitnami.com/bitnami`.
3. Instalar nginx: `helm install my-nginx bitnami/nginx`.
4. Listar releases: `helm list`.
5. Desinstalar: `helm uninstall my-nginx`.

---

## Checklist de Dominio

### Deployments e Rollouts
- [ ] Criar Deployment imperativo com `--replicas` e `--dry-run=client -o yaml`
- [ ] Rolling update + rollback com verificacao de historico
- [ ] Configurar `maxSurge` e `maxUnavailable` e observar diferenca
- [ ] Usar `Recreate` e entender quando aplicar

### ConfigMaps e Secrets
- [ ] Criar ConfigMap com `--from-literal` e `--from-file`
- [ ] Injetar ConfigMap como `env`, `envFrom` e `volumeMount`
- [ ] Criar Secret e decodificar com `base64 -d`
- [ ] Atualizar ConfigMap montado como volume e validar propagacao automatica

### Scaling e Primitivos
- [ ] Scale manual de Deployment com `kubectl scale`
- [ ] Pod com `readinessProbe` e `livenessProbe` — observar comportamento de falha
- [ ] Job com `completions` e `parallelism`
- [ ] CronJob criado, disparado e suspenso
- [ ] InitContainer aguardando dependencia

### Resource Limits e Scheduling
- [ ] Pod com `requests`/`limits` e observacao de Pending por recursos insuficientes
- [ ] LimitRange aplicando defaults automaticamente
- [ ] ResourceQuota bloqueando criacao alem do limite
- [ ] `nodeSelector` agendando pod em node especifico
