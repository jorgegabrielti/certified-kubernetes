# Sub-tópico 06 — Gestão de Manifestos

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Baixo — awareness level. Saber reconhecer estrutura Kustomize e comandos Helm básicos é suficiente.

---

## Conceitos Fundamentais

| Ferramenta | Propósito | Templating |
|------------|-----------|:----------:|
| `kubectl apply` (declarativo) | Gerencia recursos pelo estado desejado em YAML | Não |
| `kubectl create` (imperativo) | Cria recursos pontualmente | Não |
| `Kustomize` | Overlays e patches sem templates (built-in no kubectl) | Não |
| `Helm` | Package manager com templates Go | **Sim** |

---

## kubectl: Declarativo vs Imperativo

```bash
# Imperativo — cria diretamente (útil para gerar YAML na prova)
kubectl create deployment nginx --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml

# Declarativo — aplica o estado desejado
kubectl apply -f deploy.yaml
kubectl apply -f ./manifests/   # aplica toda a pasta

# Diferença:
# apply: cria se não existe, atualiza se existe, mantém campos não declarados
# create: falha se já existe
# replace: substitui completamente (--force recria)
```

---

## Kustomize

Kustomize permite personalizar manifestos sem alterar os arquivos originais (base), usando **overlays**.

### Estrutura típica

```
base/
  deployment.yaml
  service.yaml
  kustomization.yaml

overlays/
  staging/
    kustomization.yaml   # referencia base + patches
  production/
    kustomization.yaml
```

### base/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
```

### overlays/staging/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
namePrefix: staging-
replicas:
- name: nginx-deploy
  count: 2
images:
- name: nginx
  newTag: "1.25"
```

```bash
# Visualizar o resultado sem aplicar
kubectl kustomize overlays/staging/

# Aplicar
kubectl apply -k overlays/staging/
```

---

## Helm

Helm empacota aplicações Kubernetes como **charts** — coleções de templates com valores configuráveis.

### Conceitos

| Termo | O que é |
|-------|---------|
| Chart | Pacote de templates Kubernetes |
| Release | Instância de um chart instalada no cluster |
| Values | Parâmetros que personalizam um chart (`values.yaml`) |
| Repository | Repositório de charts (como apt para Debian) |

### Comandos Essenciais

```bash
# Repositórios
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/nginx

# Instalar
helm install my-nginx bitnami/nginx
helm install my-nginx bitnami/nginx --set replicaCount=3
helm install my-nginx bitnami/nginx -f custom-values.yaml

# Listar releases
helm list
helm list --all-namespaces

# Upgrade
helm upgrade my-nginx bitnami/nginx --set image.tag=1.25

# Rollback
helm rollback my-nginx 1   # volta para revisão 1

# Ver valores
helm show values bitnami/nginx
helm get values my-nginx

# Ver manifests gerados
helm template my-nginx bitnami/nginx

# Desinstalar
helm uninstall my-nginx

# Status
helm status my-nginx
```

---

## Exercícios

### 6.1 — Kustomize básico

1. Criar estrutura de base com Deployment e Service.
2. Criar overlay `staging` que:
   - Adiciona prefix `staging-` ao nome
   - Muda replicas para 2
   - Muda a tag da imagem
3. Visualizar: `kubectl kustomize overlays/staging/`
4. Aplicar: `kubectl apply -k overlays/staging/`

### 6.2 — Helm básico

1. Instalar Helm no sistema.
2. Adicionar repositório bitnami: `helm repo add bitnami https://charts.bitnami.com/bitnami`
3. Instalar nginx: `helm install my-nginx bitnami/nginx`
4. Listar releases: `helm list`
5. Ver os pods criados: `kubectl get pods -l app.kubernetes.io/instance=my-nginx`
6. Desinstalar: `helm uninstall my-nginx`
