# Upgrade de Cluster Kubernetes com kubeadm: Zero Downtime, Zero Surpresas

> **Série:** Kubernetes Descomplicado — Guia Prático para a CKA  
> **Domínio:** Cluster Architecture, Installation and Configuration (25% do exame)  
> **Cobre:** Sub-tópico 06 — Perform a Version Upgrade on a Kubernetes Cluster Using Kubeadm

---

## Por que Upgrade de Cluster Importa?

Todo cluster Kubernetes que existe em produção vai precisar de upgrade — e vai precisar de novo, e de novo. O Kubernetes lança uma nova minor version a cada quatro meses. Ficar duas ou três versões atrás significa ficar sem suporte, sem patches de segurança e fora do ciclo de compatibilidade com os componentes que você usa.

Na CKA, upgrade de cluster é uma das tarefas mais frequentes. Tem sequência definida, tem armadilhas conhecidas e é completamente possível de fazer em menos de 20 minutos quando você entende o que está fazendo.

Este artigo cobre o processo completo: do backup ao uncordon do último worker.

---

## O Ambiente

O mesmo cluster de dois nodes do artigo anterior, rodando localmente:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Host (sua máquina)                                                          │
│                                                                              │
│  ┌─────────────────────── Host-Only · 192.168.56.0/24 ───────────────────┐  │
│  │                                                                        │  │
│  │   ┌───────────────────────────┐      ┌───────────────────────────┐   │  │
│  │   │  master01                 │      │  worker01                 │   │  │
│  │   │  192.168.56.10            │      │  192.168.56.11            │   │  │
│  │   │  Control Plane            │      │  Worker                   │   │  │
│  │   │  v1.31.x  ──► v1.32.x    │      │  v1.31.x  ──► v1.32.x    │   │  │
│  │   └───────────────────────────┘      └───────────────────────────┘   │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

O exemplo usa a transição `v1.31 → v1.32`. A lógica é idêntica para qualquer minor version.

---

## As Regras do Jogo

Antes de qualquer comando, estas quatro regras precisam estar claras:

| Regra | Detalhe |
|-------|---------|
| **Um minor por vez** | Não é permitido pular versões. `v1.30 → v1.32` é inválido — você precisa passar por `v1.31` |
| **Control plane primeiro** | Sempre atualizar o master antes dos workers |
| **Workers um por vez** | Drenar → atualizar → reabilitar → próximo |
| **Repositório APT por minor** | O repositório do Kubernetes é versionado por minor version — é necessário trocá-lo a cada upgrade |

E existe uma divisão de responsabilidades que confunde bastante quem está começando:

| Ferramenta | O que atualiza |
|------------|----------------|
| `kubeadm upgrade apply` | Static pod manifests: apiserver, controller-manager, scheduler, etcd |
| `apt-get install kubelet kubectl` | Os binários dos componentes no node |
| `systemctl restart kubelet` | Aplica a nova versão do kubelet em execução |

O `kubeadm` atualiza as definições. O `apt-get` atualiza os binários. Os dois são necessários — um não substitui o outro.

---

## A Documentação é Parte da Prova

A CKA é um exame com browser aberto. A documentação oficial do Kubernetes é permitida — e usá-la é esperado. Para o upgrade de cluster, a página de referência é:

> **`kubernetes.io → Tasks → Administer a Cluster → kubeadm → Upgrading kubeadm clusters`**
> https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

Essa página contém a sequência exata de comandos para upgrade de control plane e workers. Não é necessário memorizar cada flag — é necessário saber **onde buscar** e **entender o que está executando**.

Para o backup e restore do etcd, a referência complementar é:

> **`kubernetes.io → Tasks → Administer a Cluster → Operating etcd clusters`**
> https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/

Guarde essas duas URLs. Na prova, elas são seu ponto de partida.

---

## A Sequência Completa

```
1. Backup do etcd e dos manifests        ← obrigatório, sempre
2. Verificar versão atual e alvo
3. Atualizar repositório APT

── MASTER ──────────────────────────────
4. Instalar novo kubeadm
5. kubeadm upgrade plan
6. kubeadm upgrade apply vX.Y.Z
7. Atualizar kubelet + kubectl
8. Reiniciar kubelet

── WORKER (um por vez) ─────────────────
9.  kubectl drain <worker>
10. Atualizar kubeadm + kubelet + kubectl no worker
11. kubeadm upgrade node
12. Reiniciar kubelet
13. kubectl uncordon <worker>

── VALIDAÇÃO ───────────────────────────
14. kubectl get nodes (todos Ready + nova versão)
```

---

## Passo 1 — Backup do etcd e dos Manifests (Não Pule Isso)

O etcd armazena todo o estado do cluster: Deployments, Services, Secrets, ConfigMaps — tudo. Os manifests em `/etc/kubernetes/manifests/` definem como os componentes do control plane rodam. Antes de qualquer upgrade, ambos precisam de backup.

### 1a — Encontrando os caminhos corretos no etcd.yaml

Os comandos `etcdctl` precisam de três arquivos de certificado. Em vez de decorá-los, leia diretamente do manifesto do etcd — a fonte da verdade:

```bash
cat /etc/kubernetes/manifests/etcd.yaml | grep -E 'cert-file|key-file|trusted-ca'
```

O output mostra algo assim:

```
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

Os três arquivos usados no `etcdctl` são sempre:

| Flag etcdctl | Arquivo no etcd.yaml |
|---|---|
| `--cacert` | `trusted-ca-file` → `/etc/kubernetes/pki/etcd/ca.crt` |
| `--cert` | `cert-file` → `/etc/kubernetes/pki/etcd/server.crt` |
| `--key` | `key-file` → `/etc/kubernetes/pki/etcd/ca.key` |

O diretório `/etc/kubernetes/pki/etcd/` também contém `ca.key` — a chave privada da CA do etcd. Ela não é usada no `etcdctl`, mas é crítica: sem ela, não é possível emitir novos certificados para o etcd.

### 1b — Backup do etcd

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-pre-upgrade-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Validar o snapshot
ETCDCTL_API=3 etcdctl snapshot status \
  /tmp/etcd-pre-upgrade-$(date +%Y%m%d).db --write-out=table
```

O output do `status` deve mostrar hash, revisão e número de chaves — confirma que o arquivo está íntegro.

### 1c — Backup dos Static Pod Manifests

O `kubeadm upgrade apply` reescreve os arquivos em `/etc/kubernetes/manifests/`. Se algo der errado, ter uma cópia permite reverter para a configuração anterior sem reconstruir o cluster:

```bash
cp -r /etc/kubernetes/manifests /etc/kubernetes/manifests.bak-$(date +%Y%m%d)
ls /etc/kubernetes/manifests.bak-$(date +%Y%m%d)
# kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml  etcd.yaml
```

### 1d — Restore (se necessário)

Se o upgrade precisar ser revertido:

**Restaurar os manifests:**
```bash
# Substituir os manifests atuais pelo backup
cp /etc/kubernetes/manifests.bak-<data>/*.yaml /etc/kubernetes/manifests/
# O kubelet detecta as mudanças e reinicia os static pods automaticamente
watch kubectl get pods -n kube-system
```

**Restaurar o etcd:**
```bash
# Extrair dados do snapshot para novo diretório
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-pre-upgrade-<data>.db \
  --data-dir=/var/lib/etcd-restore

# Editar o manifesto do etcd para apontar para o diretório restaurado
vim /etc/kubernetes/manifests/etcd.yaml
# Alterar: hostPath.path: /var/lib/etcd  →  /var/lib/etcd-restore

# Aguardar reinicialização (~60s)
watch kubectl get pod -n kube-system etcd-master01

# Verificar saúde
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

> **Nota:** `snapshot restore` não se conecta ao etcd em execução — ele apenas descompacta os dados para `--data-dir`. Por isso, as flags de certificado e endpoint **não são necessárias** neste comando.

---

## Passo 2 — Verificar a Versão Atual e a Alvo

```bash
kubectl get nodes
kubeadm version -o short
kubelet --version
```

Para ver quais versões estão disponíveis no repositório atual:

```bash
apt-cache madison kubeadm | head -10
```

Se a versão alvo não aparecer, o repositório APT ainda aponta para a minor anterior — o próximo passo resolve isso.

---

## Passo 3 — Trocar o Repositório APT

O repositório do Kubernetes é organizado por minor version: `pkgs.k8s.io/core:/stable:/v1.31/` é um repositório diferente de `.../v1.32/`. Para instalar pacotes de `v1.32`, o arquivo de configuração precisa apontar para o repositório correto.

```bash
# Trocar a minor version no arquivo de repositório
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list

# Confirmar a mudança
cat /etc/apt/sources.list.d/kubernetes.list

apt-get update
```

Execute este passo em **cada node** antes de instalar os pacotes naquele node.

---

## Fase 1 — Upgrade do Control Plane (master01)

Execute tudo como `root` no master01.

### Instalar o novo kubeadm

```bash
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.32.0-1.1
apt-mark hold kubeadm

# Confirmar
kubeadm version -o short
```

O padrão `unhold → instalar → hold` é repetido em todos os pacotes Kubernetes. O `apt-mark hold` impede que um `apt upgrade` desatento atualize os binários sem controle.

### Planejar o upgrade

```bash
kubeadm upgrade plan
```

O output mostra a versão atual, a versão alvo disponível e todos os componentes que serão atualizados. Leia antes de aplicar.

### Aplicar o upgrade no control plane

```bash
kubeadm upgrade apply v1.32.0 --yes
```

> **Armadilha clássica da CKA:** O `kubeadm upgrade apply` recebe a versão em SemVer puro com o prefixo `v` — por exemplo, `v1.32.0`. O sufixo `-1.1` que aparece no `apt-get install` é exclusivo do APT no Ubuntu. Passar `v1.32.0-1.1` para o `kubeadm` faz o comando falhar com erro de versão inválida.

Esse comando atualiza os static pod manifests de todos os componentes do control plane e reinicia os pods correspondentes automaticamente.

### Atualizar kubelet e kubectl no master

```bash
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl

systemctl daemon-reload
systemctl restart kubelet

# Verificar
kubectl get nodes
```

O master01 deve aparecer na nova versão. Os workers ainda vão mostrar a versão antiga — isso é esperado.

---

## Fase 2 — Upgrade dos Workers (um por vez)

### Drenar o worker (executar no master)

```bash
kubectl drain worker01 --ignore-daemonsets --delete-emptydir-data
kubectl get nodes
# worker01: SchedulingDisabled
```

`drain` faz duas coisas: cordonar o node (impedir novos pods de serem alocados) e mover os pods existentes para outros nodes. As flags:
- `--ignore-daemonsets`: DaemonSets não são removidos pelo drain — eles são tolerados
- `--delete-emptydir-data`: necessário quando algum pod usa volume `emptyDir`, que seria perdido de qualquer forma

### Atualizar o worker (executar no worker01)

```bash
# Trocar repositório APT
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list
apt-get update

# Atualizar kubeadm
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.32.0-1.1
apt-mark hold kubeadm

# Aplicar upgrade no node worker
kubeadm upgrade node
```

Note: em workers o comando é `kubeadm upgrade node`, não `kubeadm upgrade apply`. O `apply` é exclusivo do control plane. O `node` sincroniza a configuração do kubelet local com o que o master já atualizou.

```bash
# Atualizar kubelet e kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl

systemctl daemon-reload
systemctl restart kubelet
```

### Reabilitar o worker (executar no master)

```bash
kubectl uncordon worker01
kubectl get nodes
# worker01: Ready
```

Repita a sequência de drain → atualizar → uncordon para cada worker adicional.

---

## Validação Final

```bash
# Todos os nodes devem estar Ready na nova versão
kubectl get nodes -o wide

# Todos os pods do sistema devem estar Running
kubectl get pods -n kube-system

# etcd saudável
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Smoke test
kubectl create deployment smoke-test --image=nginx --replicas=2
kubectl get pods
kubectl delete deployment smoke-test
```

---

## Armadilhas Mais Comuns

| Erro | Causa | Solução |
|------|-------|---------|
| `kubeadm upgrade apply` falha com "version unstable" ou inválida | Sufixo `-1.1` passado para o kubeadm | Use apenas SemVer com `v`: `v1.32.0` |
| `kubeadm upgrade apply` falha com "version mismatch" | Tentativa de pular minor version | Fazer upgrade um minor por vez |
| Node fica em `SchedulingDisabled` | `uncordon` não foi executado | `kubectl uncordon <node>` |
| `apt-get install kubeadm=X` não encontra versão | Repositório apontando para minor anterior | Corrigir `/etc/apt/sources.list.d/kubernetes.list` e rodar `apt-get update` |
| Worker ainda na versão antiga após instalação | kubelet não reiniciou | `systemctl daemon-reload && systemctl restart kubelet` |

---

## Referência Rápida — Cheat Sheet para Prova

```bash
# ═══ MASTER ══════════════════════════════════════════════════════════════════

# Encontrar caminhos dos certificados (ler do manifesto)
grep -E 'cert-file|key-file|trusted-ca' /etc/kubernetes/manifests/etcd.yaml

# Backup ETCD
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup dos manifests
cp -r /etc/kubernetes/manifests /etc/kubernetes/manifests.bak-$(date +%Y%m%d)

# Trocar repositório APT
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list && apt-get update

# Kubeadm
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.32.0-1.1 && apt-mark hold kubeadm
kubeadm upgrade plan
kubeadm upgrade apply v1.32.0

# Kubelet + kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# ═══ WORKER (repetir para cada worker) ═══════════════════════════════════════

# No master: drenar
kubectl drain worker01 --ignore-daemonsets --delete-emptydir-data

# No worker01:
sed -i 's|v1.31|v1.32|' /etc/apt/sources.list.d/kubernetes.list && apt-get update
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.32.0-1.1 && apt-mark hold kubeadm
kubeadm upgrade node
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.0-1.1 kubectl=1.32.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# No master: reabilitar
kubectl uncordon worker01
kubectl get nodes -o wide
```

---

## Dicas do Instrutor (Transcrição da Aula Ao Vivo)

Estas dicas foram extraídas de uma aula ao vivo com instrutor certificado que realizou a CKA 3 vezes — e o upgrade de cluster caiu em **todas** elas.

> *"Em todas as versões da CKA que fiz — três vezes — sempre caiu uma questão de upgrade de cluster. É mandatório. Você precisa ter esse processo fluido na cabeça."*

**O fluxo que precisa ser mecânico (control plane):**

```
unhold kubeadm
→ trocar repositório APT para nova versão
→ apt update
→ apt install kubeadm=<nova-versão>
→ kubeadm upgrade plan
→ kubeadm upgrade apply <versão-SemVer-limpa>
→ unhold kubelet kubectl
→ apt install kubelet kubectl
→ systemctl daemon-reload && systemctl restart kubelet
→ apt-mark hold kubeadm kubelet kubectl
```

**O fluxo do worker node:**
```
kubectl drain <node> --ignore-daemonsets    # no master
→ acessa o worker node via ssh
→ mesmos passos de unhold/install
→ kubeadm upgrade node    (diferente do control plane!)
→ systemctl restart kubelet
→ apt-mark hold kubeadm kubelet kubectl
→ kubectl uncordon <node>    # de volta ao master
```

**Diferença crítica entre control plane e worker:**

| Comando | Onde executar |
|---------|--------------|
| `kubeadm upgrade apply v1.32.0` | Control plane |
| `kubeadm upgrade node` | Worker nodes |

**Sobre os binários na prova:**
> *"Provavelmente na prova os binários já vão estar baixados. Você só precisa fazer o processo de upgrade. Mas a gente sabe onde procurar — é sempre `pkgs.k8s.io/core:/stable:/v1.32/deb/`."*

**Sobre drain e uncordon:**
> *"Se cair qualquer exercício sobre preparar um nó para manutenção: `kubectl drain`. Quero que lembrem de drenar — tirar tudo que está nele. E a flag `--ignore-daemonsets` é importante porque o CNI roda em todos os nós como DaemonSet e você pode ignorar ele."*

**O certificado como bônus do upgrade:**
> *"Uma das melhores coisas do upgrade é que o kubeadm renova todos os certificados do cluster automaticamente. Por padrão os certs têm validade de 1 ano — se você não fizer upgrade, precisa renovar manualmente. Outro motivo para manter o cluster atualizado."*

**Conselho de treinamento:**
> *"É um dos processos que mais tem chance de a gente se perder no meio do caminho. Por isso precisa treinar bastante. Crie um cluster, faça o upgrade, destrua, recrie, faça mais um upgrade. Repetição é o que vai te dar performance no dia da prova."*

---

## Conclusão

Upgrade de cluster Kubernetes com kubeadm é um processo determinístico. Existem poucas variáveis: a versão de origem, a versão de destino e o número de workers. Tudo o mais segue a mesma sequência sempre.

Os dois pontos que mais causam falha na prova e em ambientes reais são:
1. **Esquecer de trocar o repositório APT** antes de tentar instalar a nova versão
2. **Passar o sufixo `-1.1` para o `kubeadm upgrade apply`** em vez de usar SemVer limpo

Pratique o ciclo completo pelo menos duas vezes. Na segunda, você consegue fazer em menos de 15 minutos — e a confiança durante a prova vale mais do que qualquer memorização.

No próximo artigo da série: **RBAC** — configurando papéis, associações e políticas de acesso no Kubernetes.

---

**Recursos:**
- [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Operating etcd clusters for Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- [CKA Curriculum Oficial v1.35](https://github.com/cncf/curriculum)

---

*Fazendo parte da série **Kubernetes Descomplicado** — documentando a jornada de estudo para a CKA com foco em entendimento real, não em memorização de comandos.*

---

### Tags sugeridas
`#Kubernetes` `#CKA` `#DevOps` `#CloudNative` `#SRE` `#kubeadm` `#ClusterUpgrade` `#Linux` `#Infrastructure` `#ContainerOrchestration`
