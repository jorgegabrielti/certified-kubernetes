# Sub-tópico 05 — Implement etcd Backup and Restore

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Alto — é uma das tarefas mais frequentes na prova CKA. Dominar os comandos exatos é essencial.

---

## Conceitos Fundamentais

### 5.1 O que é o etcd?

O **etcd** é o banco de dados chave-valor distribuído que armazena **todo o estado do cluster Kubernetes**:
- Definições de todos os objetos (Pods, Deployments, Services, ConfigMaps, Secrets, etc.)
- Estado atual de cada recurso
- Tokens de autenticação e certificados

> **Perda do etcd = perda de todo o estado do cluster.** Por isso, backup regular é obrigatório em produção.

### 5.2 Onde o etcd roda?

Em clusters criados com kubeadm, o etcd roda como um **static pod** no control plane:

```bash
# Ver o manifesto do etcd
cat /etc/kubernetes/manifests/etcd.yaml

# Ver o pod rodando
kubectl get pod -n kube-system | grep etcd

# Verificar onde os dados estão armazenados (hostPath)
grep -A2 'hostPath' /etc/kubernetes/manifests/etcd.yaml
# Por padrão: /var/lib/etcd
```

### 5.3 Localização dos certificados

Todos os comandos com `etcdctl` exigem autenticação TLS. Os certificados ficam em:

| Certificado | Caminho |
|-------------|---------|
| CA do etcd | `/etc/kubernetes/pki/etcd/ca.crt` |
| Certificado do servidor | `/etc/kubernetes/pki/etcd/server.crt` |
| Chave privada do servidor | `/etc/kubernetes/pki/etcd/server.key` |

---

## 6. Backup do etcd

### 6.1 Comando de backup (snapshot save)

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Explicação de cada flag:**

| Flag | Propósito |
|------|-----------|
| `snapshot save <arquivo>` | Salva o snapshot no caminho especificado |
| `--endpoints` | Endereço do etcd (sempre `https://127.0.0.1:2379` no kubeadm) |
| `--cacert` | CA que assinou o certificado do etcd |
| `--cert` | Certificado para autenticar na API do etcd |
| `--key` | Chave privada correspondente ao `--cert` |

### 6.2 Validar integridade do snapshot

```bash
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db \
  --write-out=table
```

Output esperado:

```
+---------+----------+------------+------------+
|  HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+---------+----------+------------+------------+
| a1b2c3d | 12345    | 987        | 3.4 MB     |
+---------+----------+------------+------------+
```

### 6.3 Boas práticas de backup

```bash
# Usar timestamp no nome do arquivo para identificar quando foi gerado
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ETCDCTL_API=3 etcdctl snapshot save /var/backups/etcd-snapshot-${TIMESTAMP}.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verificar o arquivo gerado
ls -lh /var/backups/etcd-snapshot-*.db
```

---

## 7. Restore do etcd

O restore é um processo de **3 etapas**:
1. `etcdctl snapshot restore` — extrai os dados para um novo diretório
2. Atualizar o manifesto do etcd para apontar para o novo diretório
3. Aguardar o kubelet reiniciar o pod do etcd

### 7.1 Passo 1 — Restaurar o snapshot para novo diretório

```bash
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore
```

> **Importante:** O `snapshot restore` **não** se conecta ao etcd em execução. Ele apenas extrai os dados do arquivo de snapshot para o `--data-dir`. Por isso, as flags de certificado e endpoints **não são necessárias** neste comando.

### 7.2 Passo 2 — Atualizar o manifesto do etcd

```bash
# Editar o manifesto do static pod do etcd
vim /etc/kubernetes/manifests/etcd.yaml
```

Localizar a seção `volumes` e alterar o `hostPath` do volume `etcd-data`:

```yaml
# Antes (valor original):
  - hostPath:
      path: /var/lib/etcd          # ← alterar esta linha
      type: DirectoryOrCreate
    name: etcd-data

# Depois (novo diretório restaurado):
  - hostPath:
      path: /var/lib/etcd-restore  # ← novo caminho
      type: DirectoryOrCreate
    name: etcd-data
```

### 7.3 Passo 3 — Aguardar reinicialização

O kubelet detecta a mudança no manifesto automaticamente e reinicia o pod. Isso pode demorar 30–60 segundos.

```bash
# Monitorar o pod do etcd
watch kubectl get pod -n kube-system etcd-master01

# Verificar saúde após reiniciar
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## 8. Exercícios Práticos

### Básico

**Ex 5.1 — Identificar configuração do etcd**
1. Localizar o manifesto: `cat /etc/kubernetes/manifests/etcd.yaml`.
2. Identificar onde os dados estão armazenados (`hostPath` do volume `etcd-data`).
3. Verificar o endpoint do etcd: `grep listen-client /etc/kubernetes/manifests/etcd.yaml`.
4. Localizar os certificados: `ls /etc/kubernetes/pki/etcd/`.

**Ex 5.2 — Backup e validação**
1. Executar backup: comando da seção 6.1 (salvar em `/tmp/etcd-backup.db`).
2. Validar snapshot: seção 6.2.
3. Verificar que o arquivo foi criado: `ls -lh /tmp/etcd-backup.db`.

### Intermediário

**Ex 5.3 — Backup → Alteração → Restore com validação**
1. Criar recursos de teste:
   ```bash
   kubectl create namespace restore-test
   kubectl create configmap test-cm --from-literal=key=valor -n restore-test
   kubectl create deployment nginx-test --image=nginx -n restore-test
   ```
2. Fazer backup do etcd (salvar em `/tmp/pre-delete.db`).
3. Deletar os recursos criados:
   ```bash
   kubectl delete namespace restore-test
   ```
4. Confirmar que os recursos foram removidos: `kubectl get ns restore-test` → NotFound.
5. Executar o restore completo (etapas 7.1 → 7.2 → 7.3).
6. Após reinicialização, confirmar que os recursos voltaram:
   ```bash
   kubectl get namespace restore-test
   kubectl get configmap -n restore-test
   kubectl get deployment -n restore-test
   ```

### Avançado

**Ex 5.4 — Restore com diretório nomeado por data**
1. Fazer backup com timestamp: `etcdctl snapshot save /var/backups/etcd-$(date +%Y%m%d).db ...`.
2. Restaurar para `/var/lib/etcd-$(date +%Y%m%d)` (diretório com data).
3. Atualizar o manifesto do etcd apontando para o novo `data-dir`.
4. Validar restore com verificação de recursos pré-definidos.

---

## Armadilhas Comuns (Gotchas)

| Erro | Causa | Solução |
|------|-------|---------|
| `etcdctl: command not found` | Binário não disponível no PATH | Usar `crictl exec` ou instalar etcdctl separadamente |
| Permissão negada ao acessar certificados | Não está rodando como root | Usar `sudo -i` antes dos comandos etcdctl |
| etcd não reinicia após alterar manifesto | Erro de sintaxe no YAML | Verificar indentação, reverter com `git diff` ou backup do manifesto |
| `endpoint health` retorna unhealthy | etcd ainda inicializando | Aguardar 30-60s e re-testar |
| Dados não aparecem após restore | `data-dir` errado no manifesto | Verificar `hostPath` no manifesto e confirmar que bate com o restore |
| `snapshot restore` falha com "data directory already exists" | Diretório de destino já existe | Usar um diretório novo ou limpar o existente primeiro |

---

## Referência Rápida — Comandos Críticos para Prova

```bash
# ─── BACKUP ───────────────────────────────────────────────────────────────────
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# ─── VALIDAR ──────────────────────────────────────────────────────────────────
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db --write-out=table

# ─── RESTORE ──────────────────────────────────────────────────────────────────
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore

# ─── ATUALIZAR MANIFESTO ──────────────────────────────────────────────────────
# Editar /etc/kubernetes/manifests/etcd.yaml:
# hostPath.path: /var/lib/etcd  →  /var/lib/etcd-restore

# ─── VERIFICAR SAÚDE ──────────────────────────────────────────────────────────
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## Dicas de Prova CKA

- **Memorize os 3 caminhos de certificado** — são sempre os mesmos em clusters kubeadm.
- `snapshot restore` **não precisa** das flags de certificado e endpoint — apenas `--data-dir`.
- Depois de editar o manifesto do etcd, pode demorar até **2 minutos** para o apiserver voltar — aguarde antes de testar.
- Se o etcd não subir após o restore, verifique as permissões do diretório: `chown -R etcd:etcd /var/lib/etcd-restore` (raramente necessário, mas pode acontecer).
- Na prova, anote o caminho do snapshot assim que criar — você precisará dele no restore.
