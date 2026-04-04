# Sub-tópico 04 — Primitivos para Aplicações Resilientes

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Médio — Probes e Jobs aparecem com frequência; DaemonSet e StatefulSet são contextuais.

---

## Conceitos Fundamentais

### Probes

O Kubernetes usa probes para tomar decisões sobre o estado do container:

| Probe | O que faz quando falha | Uso típico |
|-------|------------------------|------------|
| `livenessProbe` | Reinicia o container | App travado mas processo ainda rodando |
| `readinessProbe` | Remove o pod do endpoint do Service | App inicializando ou temporariamente sobrecarregado |
| `startupProbe` | Bloqueia liveness/readiness até passar | Apps com inicialização lenta |

> **Regra prática:** Sempre configure `readinessProbe`. A `livenessProbe` sem cuidado pode causar restart loops em apps que demoram a iniciar — use `startupProbe` para proteger o período de startup.

**Tipos de probe:**

```yaml
# HTTP
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

# TCP
readinessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 5
  periodSeconds: 10

# Exec (comando)
livenessProbe:
  exec:
    command: ["cat", "/tmp/healthy"]
  initialDelaySeconds: 5
  periodSeconds: 5
```

### restartPolicy

| Valor | Comportamento | Usar com |
|-------|--------------|----------|
| `Always` | Sempre reinicia (padrão) | Deployments, DaemonSets |
| `OnFailure` | Reinicia apenas se exit code != 0 | Jobs |
| `Never` | Nunca reinicia | Jobs de execução única, debug |

---

## Primitivos de Workload

### DaemonSet

Garante exatamente 1 pod por node (ou por subset com `nodeSelector`/tolerations).

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
```

Usos típicos: agentes de log, monitoramento, storage plugins, CNI.

### Job

Execução finita — termina quando o número de completions é atingido.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-calculator
spec:
  completions: 3        # total de execuções bem-sucedidas necessárias
  parallelism: 2        # quantas rodam em paralelo
  backoffLimit: 4       # tentativas antes de marcar como Failed
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
```

### CronJob

Job agendado com sintaxe cron:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: meu-cron
spec:
  schedule: "*/1 * * * *"    # a cada 1 minuto
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: hello
            image: busybox
            command: ["date"]
```

```bash
# Suspender CronJob
kubectl patch cronjob meu-cron -p '{"spec":{"suspend":true}}'

# Disparar manualmente
kubectl create job meu-cron-manual --from=cronjob/meu-cron
```

### InitContainer

Roda **antes** do container principal, de forma sequencial. O container principal só sobe após todos os initContainers terminarem com sucesso (`exit 0`).

```yaml
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh', '-c', 'until nslookup db-service; do echo waiting; sleep 2; done']
  containers:
  - name: app
    image: my-app:latest
```

Estados visíveis:
- `Init:0/1` — initContainer ainda rodando
- `Init:Error` — initContainer falhou
- `Running` — todos initContainers passaram, container principal subiu

---

## Comandos Essenciais (Prova)

```bash
# DaemonSet
kubectl get daemonset
kubectl describe daemonset <nome>

# Job
kubectl get jobs
kubectl logs job/<nome>
kubectl delete job <nome>

# CronJob
kubectl get cronjob
kubectl patch cronjob <nome> -p '{"spec":{"suspend":true}}'
kubectl create job <nome>-manual --from=cronjob/<nome>

# Verificar initContainers
kubectl describe pod <pod> | grep -A 10 "Init Containers"
kubectl logs <pod> -c <init-container-name>
```

---

## Exercícios

### 4.1 — Probes

1. Criar Deployment com `readinessProbe` HTTP:
   ```yaml
   readinessProbe:
     httpGet:
       path: /
       port: 80
     initialDelaySeconds: 5
     periodSeconds: 10
   ```
2. Fazer a probe falhar alterando o path para `/fail` — observar que o pod para de receber tráfego mas **não reinicia**.
3. Adicionar `livenessProbe` na mesma rota — agora o pod **reinicia** ao falhar.
4. Adicionar `startupProbe` com `failureThreshold: 30` para simular app de inicialização lenta.

### 4.2 — DaemonSet

1. Criar DaemonSet com `busybox` executando `sleep 3600`.
2. Confirmar: `kubectl get pods -o wide` — deve haver 1 pod por worker node.
3. Verificar que novos pods surgem automaticamente ao adicionar nodes.

### 4.3 — Job com paralelismo

1. Criar Job com `completions: 3` e `parallelism: 2`:
   ```bash
   kubectl create job pi-job --image=perl -- perl -Mbignum=bpi -wle 'print bpi(2000)'
   ```
   (editar para adicionar completions/parallelism via `--dry-run=client -o yaml`)
2. Observar pods rodando em paralelo: `kubectl get pods -w`
3. Ver os logs: `kubectl logs job/pi-job`

### 4.4 — CronJob

1. Criar CronJob que executa `date` a cada minuto:
   ```bash
   kubectl create cronjob date-cron --image=busybox --schedule="*/1 * * * *" -- date
   ```
2. Aguardar 2 execuções e verificar: `kubectl get jobs`
3. Suspender: `kubectl patch cronjob date-cron -p '{"spec":{"suspend":true}}'`
4. Disparar manualmente: `kubectl create job date-cron-manual --from=cronjob/date-cron`

### 4.5 — InitContainer

1. Criar pod com initContainer que aguarda um Service:
   ```yaml
   initContainers:
   - name: wait-svc
     image: busybox
     command: ['sh', '-c', 'until nslookup meu-servico; do sleep 2; done']
   ```
2. Verificar que o pod fica em `Init:0/1`.
3. Criar o Service `meu-servico` e confirmar que o pod progride para `Running`.
