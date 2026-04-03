---
name: k8s-yaml-exercises
description: "Use this skill when writing, reviewing, or debugging Kubernetes YAML manifests for CKA/CKAD/CKS practice exercises. Covers field names, apiVersion/kind matrix, common pitfalls, and validation workflow."
---

# Skill: k8s-yaml-exercises

## When this skill applies

Trigger phrases: **YAML**, **manifest**, **pod spec**, **deployment**, **configmap**, **secret**, **volume**, **env**, **kubectl apply**, **exercise**, any `.yaml` file under `CKA/`, `CKAD/`, or `CKS/`.

---

## Mandatory YAML Header

Every manifest file must start with:

```yaml
apiVersion: <group/version>   # e.g. apps/v1, v1, batch/v1
kind: <Kind>
metadata:
  name: <name>
  namespace: <namespace>      # omit only for cluster-scoped resources
```

### apiVersion + Kind Quick Reference

| Kind | apiVersion |
|------|-----------|
| Pod | `v1` |
| Deployment | `apps/v1` |
| ReplicaSet | `apps/v1` |
| DaemonSet | `apps/v1` |
| StatefulSet | `apps/v1` |
| Job | `batch/v1` |
| CronJob | `batch/v1` |
| Service | `v1` |
| ConfigMap | `v1` |
| Secret | `v1` |
| PersistentVolume | `v1` |
| PersistentVolumeClaim | `v1` |
| StorageClass | `storage.k8s.io/v1` |
| Ingress | `networking.k8s.io/v1` |
| NetworkPolicy | `networking.k8s.io/v1` |
| HorizontalPodAutoscaler | `autoscaling/v2` |
| ServiceAccount | `v1` |
| ClusterRole / Role | `rbac.authorization.k8s.io/v1` |
| ClusterRoleBinding / RoleBinding | `rbac.authorization.k8s.io/v1` |
| LimitRange | `v1` |
| ResourceQuota | `v1` |

---

## Container Spec — Most Common Mistakes

### Commands and args

```yaml
# CORRECT
spec:
  containers:
  - name: app
    image: nginx:1.25
    command: ["sh", "-c"]       # ← singular "command", not "commands"
    args: ["echo hello"]
```

**Never use `commands:` (plural) — it is not a valid field.**

### Environment variables

```yaml
env:
- name: MY_VAR           # ← "name" is REQUIRED — never leave empty
  value: "literal-value"

- name: FROM_CONFIGMAP
  valueFrom:
    configMapKeyRef:
      name: my-configmap
      key: existing-key   # ← must match an actual key in the ConfigMap

- name: FROM_SECRET
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: existing-key
```

**Rule:** Before using `configMapKeyRef.key` or `secretKeyRef.key`, verify the key exists with:
```bash
kubectl get configmap <name> -o yaml
kubectl get secret <name> -o yaml
```

---

## Volumes and VolumeMounts

```yaml
spec:
  volumes:
  - name: config-vol          # ← name must match volumeMounts[].name exactly
    configMap:
      name: my-configmap
      items:
      - key: app.conf         # ← key must exist in the ConfigMap
        path: app.conf        # ← path is REQUIRED when items[] is specified

  containers:
  - name: app
    volumeMounts:
    - name: config-vol        # ← must match volumes[].name exactly
      mountPath: /etc/config
```

**Rules:**
- `spec.volumes[].configMap.items[].path` is **REQUIRED** when `items[]` is specified
- Volume name in `spec.volumes[]` must exactly match `spec.containers[].volumeMounts[].name`
- `mountPath` is the directory inside the container — the file will appear as `mountPath/path`

---

## Immutable Pod Fields

These fields **cannot be changed** on a running Pod via `kubectl apply`:
- `spec.containers[].image` (use `kubectl set image` on Deployments instead)
- `spec.containers[]` list additions/removals
- `spec.volumes[]`
- `spec.nodeSelector`

**To update an immutable field:**
```bash
kubectl replace --force -f <manifest.yaml>
# This deletes the pod and recreates it — data in emptyDir volumes is lost
```

**Note:** `kubectl apply` on a Pod with immutable field changes silently leaves the old Pod running with the old spec.

---

## Probe Patterns

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3

readinessProbe:
  tcpSocket:
    port: 5432
  initialDelaySeconds: 5
  periodSeconds: 10

startupProbe:
  exec:
    command: ["cat", "/tmp/ready"]
  failureThreshold: 30
  periodSeconds: 10
```

---

## Resource Requests and Limits

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "64Mi"
  limits:
    cpu: "500m"
    memory: "128Mi"
```

- CPU throttled when over limit (never killed)
- Memory OOMKilled when over limit (pod restarted)
- `requests` affect scheduling; `limits` affect runtime behavior

---

## Labels and Selectors — Must Match

```yaml
# Deployment: selector must match template labels
spec:
  selector:
    matchLabels:
      app: my-app           # ← these two
  template:
    metadata:
      labels:
        app: my-app         # ← must match exactly
```

---

## Validation Workflow

Before committing a YAML:

```bash
# 1. Dry-run against the API server (best validation)
kubectl apply --dry-run=server -f manifest.yaml

# 2. Check for field errors
kubectl apply -f manifest.yaml

# 3. Verify state
kubectl get pod <name> -o wide
kubectl describe pod <name>         # look for Events section
kubectl logs <name>                  # check container output
```

**Never submit a YAML that has not been dry-run validated.**

---

## CKA Exam Speed Tips

```bash
# Generate YAML stubs imperatively
kubectl run mypod --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deploy myapp --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml
kubectl create configmap myconf --from-literal=key1=val1 --dry-run=client -o yaml > cm.yaml
kubectl create secret generic mysec --from-literal=pass=secret --dry-run=client -o yaml > secret.yaml

# Force delete + recreate
kubectl replace --force -f manifest.yaml
```
