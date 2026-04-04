# ConfigMaps e Secrets — Configurando Aplicações no Kubernetes

> **Série:** Kubernetes Descomplicado — Guia Prático para a CKA  
> **Domínio:** Workloads and Scheduling (15% do exame)  
> **Cobre:** Sub-tópico 2 — Use ConfigMaps and Secrets to configure applications

---

## Por que separar configuração do código?

A imagem de container deve ser imutável — o mesmo artefato vai para staging e produção. O que muda é a **configuração**: endpoints de banco, credenciais, parâmetros de comportamento.

O Kubernetes resolve isso com dois objetos:

| Objeto | Para quê | Proteção |
|--------|----------|----------|
| `ConfigMap` | Configuração não-sensível | Nenhuma — texto puro |
| `Secret` | Credenciais, tokens, certificados | base64 (encode, não criptografia) |

> **Atenção:** Secrets não são criptografados por padrão no etcd. Em produção, habilite [Encryption at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/). Na prova da CKA, use-os como são.

---

## ConfigMap

### Criação

**Imperativo — chave a chave:**
```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080
```

**Imperativo — a partir de arquivo:**
```bash
kubectl create configmap nginx-config --from-file=nginx.conf
# a chave será o nome do arquivo: "nginx.conf"
```

**Imperativo — a partir de arquivo com chave personalizada:**
```bash
kubectl create configmap nginx-config --from-file=meu-nginx=nginx.conf
```

**Declarativo (YAML):**
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

> **Nota:** Chaves com ponto (`key.parameters`) são válidas. Quando montadas como arquivo em volume, o nome do arquivo será exatamente o nome da chave.

---

## Formas de Injeção

Existem três formas de usar um ConfigMap num pod. Entender a diferença é essencial para a prova.

### 1. Variável de ambiente — chave específica (`configMapKeyRef`)

```yaml
env:
- name: ENV_KEY2
  valueFrom:
    configMapKeyRef:
      name: primeiro-configmap
      key: key1
```

Resultado: a variável `ENV_KEY2` terá o valor de `key1` do ConfigMap.

### 2. Variável de ambiente — todo o ConfigMap (`envFrom`)

```yaml
envFrom:
- configMapRef:
    name: primeiro-configmap
```

Resultado: cada chave do ConfigMap vira uma variável de ambiente com seu próprio nome.

### 3. Volume montado

```yaml
spec:
  volumes:
  - name: configmap
    configMap:
      name: primeiro-configmap
      items:
      - key: key.parameters      # qual chave do ConfigMap
        path: key.parameters     # nome do arquivo dentro do mountPath
  containers:
  - name: app
    volumeMounts:
    - name: configmap
      mountPath: /etc/podconfig
      readOnly: true
```

> **Armadilha:** Quando `items` é especificado, `path` é **obrigatório** — sem ele, o Kubernetes rejeita o pod com `Required value`. Se `items` for omitido, todas as chaves são montadas automaticamente como arquivos.

**Comportamento de propagação:**

| Método | Propaga mudanças no ConfigMap? |
|--------|-------------------------------|
| `env` / `envFrom` | **Não** — requer reinício do pod |
| `volumeMount` | **Sim** — automático em < 60s |

---

## Manifesto Completo — Pod com ConfigMap (pod3.yaml praticado)

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
        path: key.parameters
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
      value: "value1"                     # valor literal (não vem do ConfigMap)
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

**Validação:**
```bash
# Verificar variáveis injetadas
kubectl exec configmap-completo -- env | grep ENV_

# Verificar arquivo montado
kubectl exec configmap-completo -- cat /etc/podconfig/key.parameters
```

---

## Secret

### Criação

```bash
# Opaque (tipo padrão)
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=senha123 \
  --from-literal=DB_USER=admin

# A partir de arquivo (certificados, chaves)
kubectl create secret generic tls-secret \
  --from-file=tls.crt --from-file=tls.key

# TLS (tipo específico)
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key
```

### Inspecionar e decodificar

```bash
# Ver o Secret (valores em base64)
kubectl get secret app-secret -o yaml

# Decodificar um valor específico
kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### Usar como variável de ambiente

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: DB_PASSWORD
```

### Usar como volume

```yaml
spec:
  volumes:
  - name: secret-vol
    secret:
      secretName: app-secret
  containers:
  - name: app
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
      readOnly: true
```

Cada chave do Secret vira um arquivo em `/etc/secrets/`.

---

## Armadilhas Comuns (vistas na prática)

### `unknown field "spec.containers[0].commands"`

```yaml
# ERRADO
commands: ["/bin/bash"]

# CORRETO
command: ["/bin/bash"]
```

O campo é `command` no singular. Kubernetes usa strict decoding — qualquer campo desconhecido causa rejeição imediata.

### `spec.volumes[0].configMap.items[0].path: Required value`

```yaml
# ERRADO
items:
- key: key.parameters

# CORRETO
items:
- key: key.parameters
  path: key.parameters
```

### `couldn't find key X in ConfigMap`

O pod é criado com `CreateContainerConfigError` e fica em loop. Para diagnosticar:
```bash
kubectl describe pod <pod> | grep -A 5 Events
kubectl get configmap <nome> -o yaml   # verificar as chaves disponíveis
```

Para corrigir sem recriar o pod (se a chave existe mas com nome diferente):
```bash
kubectl delete pod <nome> --force --grace-period=0
kubectl apply -f pod.yaml
```

> **Por que `kubectl apply` não resolve?** O apply atualiza o manifesto, mas não recria pods existentes. A mudança só entra em vigor quando o pod for recriado (manualmente ou via Deployment rollout).

### Pod com `Forbidden: pod updates may not add or remove containers`

Campos de containers são imutáveis numa atualização de pod. Use:
```bash
kubectl replace --force -f pod.yaml
```

---

## Referência Rápida de Comandos

```bash
# ConfigMap
kubectl create configmap <nome> --from-literal=k=v
kubectl create configmap <nome> --from-file=<arquivo>
kubectl get configmap <nome> -o yaml
kubectl describe configmap <nome>
kubectl edit configmap <nome>
kubectl delete configmap <nome>

# Secret
kubectl create secret generic <nome> --from-literal=k=v
kubectl get secret <nome> -o yaml
kubectl get secret <nome> -o jsonpath='{.data.<chave>}' | base64 -d
kubectl delete secret <nome>

# Diagnóstico de pods com ConfigMap/Secret
kubectl describe pod <pod> | grep -E "Error|Events|Mounts|Environment" -A 5
kubectl exec <pod> -- env | grep <PREFIX>
kubectl exec <pod> -- ls /caminho/montado
kubectl exec <pod> -- cat /caminho/montado/<chave>
```

---

## Exercícios

### 2.1 — ConfigMap como variáveis de ambiente

1. Criar ConfigMap:
   ```bash
   kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=APP_PORT=8080
   ```
2. Criar pod que injeta todo o ConfigMap via `envFrom`:
   ```yaml
   spec:
     containers:
     - name: app
       image: alpine:latest
       command: ["sleep", "3600"]
       envFrom:
       - configMapRef:
           name: app-config
   ```
3. Validar:
   ```bash
   kubectl exec <pod> -- env | grep APP_
   ```

### 2.2 — ConfigMap como arquivo montado

1. Criar ConfigMap com conteúdo de arquivo:
   ```bash
   echo "server_name localhost;" > nginx-snippet.conf
   kubectl create configmap nginx-config --from-file=nginx-snippet.conf
   ```
2. Montar como volume e validar:
   ```bash
   kubectl exec <pod> -- cat /etc/nginx/nginx-snippet.conf
   ```

### 2.3 — Secret como variável de ambiente

1. Criar Secret:
   ```bash
   kubectl create secret generic db-secret --from-literal=DB_PASSWORD=supersecreta
   ```
2. Criar pod com `secretKeyRef`.
3. Validar:
   ```bash
   kubectl exec <pod> -- printenv DB_PASSWORD
   ```
4. Confirmar o valor original:
   ```bash
   kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
   ```

### 2.4 — Propagação de ConfigMap via volume

1. Criar pod com ConfigMap montado como volume.
2. Atualizar o ConfigMap:
   ```bash
   kubectl edit configmap app-config
   ```
3. Aguardar ~30-60s e verificar dentro do pod que o arquivo foi atualizado.
4. Comparar com um pod que usa `envFrom` — a variável de ambiente **não** muda sem reinício.
