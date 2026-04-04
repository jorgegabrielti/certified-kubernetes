# Sub-tópico 02 — ConfigMaps e Secrets

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — injeção de configuração aparece em praticamente todos os exercícios de workload.

---

## Conceitos Fundamentais

| Objeto | Para quê | Proteção |
|--------|----------|----------|
| `ConfigMap` | Configuração não-sensível | Nenhuma — texto puro |
| `Secret` | Credenciais, tokens, certificados | base64 (encode, não criptografia) |

> Secrets não são criptografados por padrão no etcd. Na prova, use como são.

### Formas de Injeção

| Método | Como | Propaga mudanças? |
|--------|------|:-----------------:|
| `env` com `configMapKeyRef` | Chave específica como variável | Não |
| `envFrom` com `configMapRef` | Todo o ConfigMap como variáveis | Não |
| `volumeMount` com `configMap` | Chaves como arquivos montados | **Sim** (< 60s) |

---

## Manifestos de Referência

### configMap.yaml

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

> Chaves com ponto (`key.parameters`) são válidas — quando montadas como volume, o nome do arquivo será exatamente o nome da chave.

### env.yaml — variáveis literais

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: env-container
    image: nginx:latest
    env:
    - name: ENV_VAR1
      value: "value1"
    - name: ENV_VAR2
      value: "value2"
```

### pod.yaml — pod com command

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: primeiro-pod
spec:
  containers:
  - name: httpd
    image: httpd:latest
    ports:
    - containerPort: 80
    command: ["/bin/bash"]
    args: ["-c", "while true; do echo CKA; sleep 10; done"]
```

### pod3.yaml — ConfigMap via env e volume (praticado)

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
        path: key.parameters   # obrigatório quando 'key' é especificado
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

---

## Armadilhas Encontradas na Prática

| Erro | Causa | Correção |
|------|-------|----------|
| `unknown field "spec.containers[0].commands"` | Campo inexistente | Usar `command` (singular) |
| `spec.volumes[0].configMap.items[0].path: Required value` | `path` obrigatório quando `key` é definido | Adicionar `path: <nome>` |
| `spec.containers[0].env[N].name: Required value` | `name:` vazio no env | Preencher o nome da variável |
| `couldn't find key X in ConfigMap` | Chave não existe | `kubectl get cm <nome> -o yaml` para verificar |
| Pod não recria ao `kubectl apply` | apply não recria pods existentes | `kubectl delete pod <nome>` + `kubectl apply` ou `kubectl replace --force` |
| `Forbidden: pod updates may not add or remove containers` | Campos de container são imutáveis | `kubectl replace --force -f pod.yaml` |

---

## Comandos Essenciais (Prova)

```bash
# ConfigMap
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080

kubectl create configmap nginx-config --from-file=nginx.conf

kubectl get configmap primeiro-configmap -o yaml
kubectl describe configmap primeiro-configmap

# Secret
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=senha123

kubectl get secret app-secret -o yaml
kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Diagnóstico
kubectl describe pod <pod> | grep -E "Error|Events|Environment|Mounts" -A 5
kubectl exec <pod> -- env | grep ENV_
kubectl exec <pod> -- cat /etc/podconfig/key.parameters
```

---

## Exercícios

### 2.1 — ConfigMap como variáveis de ambiente

1. Criar ConfigMap:
   ```bash
   kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=APP_PORT=8080
   ```
2. Criar pod com `envFrom`:
   ```yaml
   envFrom:
   - configMapRef:
       name: app-config
   ```
3. Validar: `kubectl exec <pod> -- env | grep APP_`

### 2.2 — ConfigMap como arquivo montado

1. Criar ConfigMap de arquivo:
   ```bash
   echo "worker_processes 1;" > nginx-snippet.conf
   kubectl create configmap nginx-config --from-file=nginx-snippet.conf
   ```
2. Montar via volumeMount e validar:
   ```bash
   kubectl exec <pod> -- cat /etc/nginx/nginx-snippet.conf
   ```

### 2.3 — Secret como variável de ambiente

1. Criar: `kubectl create secret generic db-secret --from-literal=DB_PASSWORD=s3cr3t`
2. Criar pod com `secretKeyRef`.
3. Validar: `kubectl exec <pod> -- printenv DB_PASSWORD`
4. Decodificar: `kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d`

### 2.4 — Propagação de ConfigMap via volume

1. Criar pod com ConfigMap montado como volume.
2. Atualizar o ConfigMap: `kubectl edit configmap app-config`
3. Aguardar ~30-60s e verificar que o arquivo atualizou dentro do pod.
4. Confirmar que variáveis via `envFrom` **não** mudaram sem reinício do pod.

---

## Arquivos desta pasta

| Arquivo | Descrição |
|---------|-----------|
| `configMap.yaml` | ConfigMap `primeiro-configmap` praticado |
| `env.yaml` | Pod com variáveis de ambiente literais |
| `pod.yaml` | Pod básico com `command` |
| `pod3.yaml` | Pod com ConfigMap via env e volume (exercício completo) |
