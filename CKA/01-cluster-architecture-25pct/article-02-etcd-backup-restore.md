# etcd Backup e Restore: Protegendo o Coração do Seu Cluster Kubernetes

> **Série:** Kubernetes Descomplicado — Guia Prático para a CKA  
> **Domínio:** Cluster Architecture, Installation and Configuration (25% do exame)  
> **Cobre:** Sub-tópico 05 — Implement etcd Backup and Restore

---

## O etcd é o Cluster

Quando você roda `kubectl apply`, `kubectl create` ou qualquer outro comando, o que acontece por baixo é uma escrita no **etcd** — um banco de dados chave-valor distribuído que armazena todo o estado do cluster Kubernetes:

- Definições de todos os objetos: Pods, Deployments, Services, ConfigMaps, Secrets
- Estado atual de cada recurso
- Tokens de autenticação e certificados do cluster

Não existe "estado do cluster" separado do etcd. Se o etcd for perdido sem backup, o cluster precisa ser reconstruído do zero — e todo o workload que existia vai junto.

Por isso, backup de etcd não é opcional. É um pré-requisito para qualquer operação destrutiva ou de alto risco, como um upgrade de versão.

---

## Onde o etcd Roda

Em clusters criados com kubeadm, o etcd roda como um **static pod** no control plane — gerenciado diretamente pelo kubelet, sem passar pelo apiserver:

```bash
# Ver o pod
kubectl get pod -n kube-system | grep etcd

# Ver o manifesto
cat /etc/kubernetes/manifests/etcd.yaml

# Ver onde os dados estão armazenados (hostPath do volume etcd-data)
grep -A2 'hostPath' /etc/kubernetes/manifests/etcd.yaml
# Por padrão: /var/lib/etcd
```

Os dados do etcd vivem em `/var/lib/etcd` no node master. O manifesto do pod é a peça central tanto do backup quanto do restore — você vai precisar editá-lo durante a restauração.

---

## Os Certificados do etcd

Todos os comandos `etcdctl` exigem autenticação TLS. Em clusters kubeadm, os caminhos são sempre os mesmos:

| Certificado | Caminho |
|---|---|
| CA do etcd | `/etc/kubernetes/pki/etcd/ca.crt` |
| Certificado do servidor | `/etc/kubernetes/pki/etcd/server.crt` |
| Chave privada do servidor | `/etc/kubernetes/pki/etcd/server.key` |

Memorize esses três caminhos. Eles aparecem em todos os comandos etcdctl na prova.

---

## Backup — Criando o Snapshot

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

O que cada flag faz:

| Flag | Propósito |
|---|---|
| `snapshot save <arquivo>` | Salva o snapshot no caminho especificado |
| `--endpoints` | Endereço do etcd — sempre `https://127.0.0.1:2379` em clusters kubeadm |
| `--cacert` | CA que assinou o certificado do etcd |
| `--cert` | Certificado para autenticar na API do etcd |
| `--key` | Chave privada correspondente ao `--cert` |

Em ambientes de produção, inclua um timestamp para identificar quando o backup foi gerado:

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ETCDCTL_API=3 etcdctl snapshot save /var/backups/etcd-${TIMESTAMP}.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Validando o snapshot

Sempre valide o arquivo após o backup:

```bash
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db --write-out=table
```

Output esperado:

```
+---------+----------+------------+------------+
|  HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+---------+----------+------------+------------+
| a1b2c3d |    12345 |        987 |    3.4 MB  |
+---------+----------+------------+------------+
```

Hash, revisão e número de chaves preenchidos = snapshot íntegro e utilizável.

---

## Restore — Recuperando o Estado do Cluster

O restore é um processo de três etapas. Entender o que cada etapa faz é mais importante do que decorar os comandos.

```
Etapa 1: etcdctl snapshot restore → extrai dados para novo diretório
Etapa 2: editar manifesto do etcd → apontar para o novo diretório
Etapa 3: aguardar kubelet reiniciar o pod do etcd
```

### Etapa 1 — Restaurar o snapshot para um novo diretório

```bash
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore
```

> **Diferença importante:** O `snapshot restore` **não** se conecta ao etcd em execução. Ele apenas descompacta os dados do arquivo para o `--data-dir`. Por isso, as flags de certificado e endpoint **não são necessárias** neste comando — ao contrário do `snapshot save`.

### Etapa 2 — Atualizar o manifesto do etcd

O pod do etcd precisa ser redirecionado para o novo diretório. Edite o manifesto do static pod:

```bash
vim /etc/kubernetes/manifests/etcd.yaml
```

Localize a seção `volumes` e altere o `hostPath` do volume chamado `etcd-data`:

```yaml
# Antes:
  - hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data

# Depois:
  - hostPath:
      path: /var/lib/etcd-restore
      type: DirectoryOrCreate
    name: etcd-data
```

### Etapa 3 — Aguardar a reinicialização

O kubelet detecta a mudança no manifesto automaticamente e reinicia o pod. Isso pode levar de 30 segundos a 2 minutos.

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

`127.0.0.1:2379 is healthy` = restore bem-sucedido.

---

## Exercício: Backup → Destruição → Restore

Este exercício é a forma mais completa de validar que o fluxo funciona:

```bash
# 1. Criar recursos de teste
kubectl create namespace restore-test
kubectl create configmap test-cm --from-literal=key=valor -n restore-test
kubectl create deployment nginx-test --image=nginx -n restore-test

# 2. Fazer backup
ETCDCTL_API=3 etcdctl snapshot save /tmp/pre-delete.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 3. Deletar os recursos
kubectl delete namespace restore-test

# 4. Confirmar que foram removidos
kubectl get ns restore-test   # deve retornar NotFound

# 5. Executar restore
ETCDCTL_API=3 etcdctl snapshot restore /tmp/pre-delete.db \
  --data-dir=/var/lib/etcd-restore

# 6. Editar manifesto — hostPath: /var/lib/etcd-restore
vim /etc/kubernetes/manifests/etcd.yaml

# 7. Aguardar reinicialização (~60s) e verificar
kubectl get namespace restore-test
kubectl get configmap -n restore-test
kubectl get deployment -n restore-test
```

Os três recursos devem aparecer novamente. O que aconteceu depois do backup simplesmente não existe mais para o cluster.

---

## Armadilhas Mais Comuns

| Erro | Causa | Solução |
|---|---|---|
| Permissão negada ao acessar certificados | Não está rodando como root | Use `sudo -i` antes dos comandos etcdctl |
| etcd não reinicia após editar manifesto | Erro de sintaxe no YAML | Verifique indentação; reverta o manifesto se necessário |
| `endpoint health` retorna unhealthy logo após restore | etcd ainda inicializando | Aguarde 60s e teste novamente |
| Dados não aparecem após restore | `hostPath` no manifesto aponta para diretório errado | Confirme que o path no manifesto bate com o `--data-dir` do restore |
| `snapshot restore` falha com "data directory already exists" | Diretório de destino já existe | Use um diretório novo (`/var/lib/etcd-restore-2`, etc.) |

---

## Referência Rápida — Cheat Sheet para Prova

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
# (sem flags de cert/endpoint — não conecta ao etcd em execução)
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore

# ─── ATUALIZAR MANIFESTO ──────────────────────────────────────────────────────
# vim /etc/kubernetes/manifests/etcd.yaml
# hostPath.path: /var/lib/etcd  →  /var/lib/etcd-restore

# ─── VERIFICAR SAÚDE ──────────────────────────────────────────────────────────
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## Dicas do Instrutor (Transcrição da Aula Ao Vivo)

Estas dicas foram extraídas de uma aula ao vivo com instrutor que já realizou a CKA 3 vezes e confirma: **backup/restore de etcd cai em todas as provas.**

> *"Em todas as minhas versões da CKA — já fiz três — sempre teve uma pergunta de upgrade de cluster e sempre teve uma de backup e restore de etcd. Nunca tive uma prova sem esses dois."*

**Os 3 tipos de questão que podem aparecer:**

| Tipo | O que pede |
|------|-----------|
| 1 | Apenas fazer o snapshot (backup) e salvar num path específico |
| 2 | Restaurar um snapshot que já existe em um path fornecido |
| 3 | Fazer backup E depois restaurar de outro arquivo |

**Dica crítica sobre os 3 lugares para editar no restore:**
> *"Piso restore, preciso trocar em **três lugares** no `etcd.yaml`: nos dois volumes (hostPath) e dentro do `--data-dir`. Se você esquecer um, o etcd não sobe, o cluster fica quebrado e você perde pontos."*

**Sobre os caminhos dos certificados:**
> *"Nunca pegou um caso que fosse diferente disso na prova — são sempre os caminhos padrão do kubeadm. Se você decorar `/etc/kubernetes/pki/etcd/{ca.crt, server.crt, server.key}`, pode simplesmente digitar sem nem precisar procurar. Mas sempre confirme no `etcd.yaml` para ter certeza."*

**O restore NÃO usa certificados:**
> *"Snapshot save usa todas as flags de cert. Snapshot restore: só passa o `--data-dir` e o arquivo. Sem `--cacert`, sem `--cert`, sem `--key`. Muita gente erra copiando o comando do save e esquecendo de retirar as flags."*

**Técnica para forçar restart do etcd quando trava:**
```bash
# Move os manifests para fora da pasta (etcd e apiserver param)
mv /etc/kubernetes/manifests/etcd.yaml /tmp/
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Aguarda os pods sumirem, depois devolve
mv /tmp/etcd.yaml /etc/kubernetes/manifests/
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

**Verificação obrigatória após restore:**
> *"Deixa uma dica aí: fiz o restore, faz um `kubectl get cm` e um `kubectl get deployment` antes de encerrar a questão. A prova é corrigida de forma automatizada — eles provavelmente vão verificar se algum recurso que existia antes do restore voltou. Garante que o cluster está disponível e os dados voltaram."*

**Extensão do arquivo:**
> *"Lembra sempre de colocar `.db` na extensão do arquivo de snapshot. O path que ele te passa na pergunta vai estar completo — você só precisa usar exatamente o que foi pedido."*

---

## Conclusão

Backup de etcd é simples quando você entende o que cada parte faz. O `snapshot save` conecta ao etcd e tira uma foto do estado. O `snapshot restore` descompacta essa foto para um diretório. A edição do manifesto aponta o pod do etcd para o novo diretório. O kubelet faz o resto.

Três caminhos de certificado para memorizar. Um diretório diferente no manifesto para editar em **três lugares**. Um comando de restore que **não** usa certificados. Esses são os detalhes que fazem a diferença entre acertar ou errar essa tarefa na prova.

No próximo artigo da série: **upgrade de cluster** — agora com o backup de etcd como primeiro passo do processo.

---

**Recursos:**
- [Documentação: Operating etcd clusters](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- [CKA Curriculum Oficial v1.35](https://github.com/cncf/curriculum)

---

*Fazendo parte da série **Kubernetes Descomplicado** — documentando a jornada de estudo para a CKA com foco em entendimento real, não em memorização de comandos.*

---

### Tags sugeridas
`#Kubernetes` `#CKA` `#DevOps` `#CloudNative` `#SRE` `#etcd` `#DisasterRecovery` `#BackupAndRestore` `#kubeadm` `#Infrastructure`
