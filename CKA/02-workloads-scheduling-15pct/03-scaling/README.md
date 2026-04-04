# Sub-tópico 03 — Scaling de Aplicações

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Médio — scaling manual é simples; HPA requer metrics-server instalado.

---

## Conceitos Fundamentais

| Mecanismo | Como funciona | Quando usar |
|-----------|--------------|-------------|
| `kubectl scale` | Altera `spec.replicas` manualmente | Scaling pontual, exercícios de prova |
| `HorizontalPodAutoscaler` (HPA) | Escala automaticamente por CPU/memória | Carga variável; requer metrics-server |
| `replicas` no manifesto + `kubectl apply` | Declarativo — git como fonte de verdade | Produção com GitOps |
| `PodDisruptionBudget` | Limita pods indisponíveis durante scale-down | Proteger disponibilidade mínima |

---

## Comandos Essenciais (Prova)

```bash
# Scale manual
kubectl scale deployment/my-app --replicas=5

# Scale via patch
kubectl patch deployment my-app -p '{"spec":{"replicas":5}}'

# Observar em tempo real
kubectl get pods -w
kubectl get deployment my-app -w

# HPA (requer metrics-server)
kubectl autoscale deployment my-app --cpu-percent=50 --min=2 --max=10

# Ver estado do HPA
kubectl get hpa
kubectl describe hpa my-app

# Instalar metrics-server no kind (adicionar --kubelet-insecure-tls)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

---

## Manifesto de Referência — HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

---

## Manifesto de Referência — PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2        # ou use maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
```

---

## Exercícios

### 3.1 — Scale manual

1. Criar Deployment com `replicas: 2`:
   ```bash
   kubectl create deployment my-app --image=nginx --replicas=2
   ```
2. Escalar para 5:
   ```bash
   kubectl scale deployment/my-app --replicas=5
   ```
3. Observar criação dos pods: `kubectl get pods -w`
4. Reduzir para 1 e observar terminação.
5. Confirmar que `kubectl get deployment my-app` mostra `READY 1/1`.

### 3.2 — HorizontalPodAutoscaler

> Requer metrics-server instalado e pods com `requests.cpu` definido.

1. Criar Deployment com resource requests:
   ```yaml
   resources:
     requests:
       cpu: "100m"
   ```
2. Criar HPA:
   ```bash
   kubectl autoscale deployment my-app --cpu-percent=50 --min=2 --max=10
   ```
3. Gerar carga (em outro terminal):
   ```bash
   kubectl run load-gen --image=busybox --restart=Never -- \
     /bin/sh -c "while true; do wget -q -O- http://<pod-ip>; done"
   ```
4. Observar scale-up: `kubectl get hpa -w`
5. Parar a carga e aguardar scale-down (pode levar alguns minutos).

### 3.3 — PodDisruptionBudget

1. Criar Deployment com `replicas: 3`.
2. Criar PDB com `minAvailable: 2`.
3. Tentar drenar um node: `kubectl drain <node> --ignore-daemonsets`
4. Observar que o drain respeita o PDB e aguarda antes de evict.
