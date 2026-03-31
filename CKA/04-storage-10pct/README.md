# Storage — 10%

Referencia: [CKA Curriculum v1.35](../CKA_Curriculum_v1.35.pdf)

---

## Sub-topicos

| # | Topico | Peso estimado |
|---|--------|---------------|
| 1 | Understand storage classes, persistent volumes | Alto |
| 2 | Understand volume mode, access modes and reclaim policies for volumes | Alto |
| 3 | Understand persistent volume claims primitive | Alto |
| 4 | Know how to configure applications with persistent storage | Medio |

---

## 1. StorageClass e PersistentVolumes

### Conceitos
- `StorageClass` — define como o provisionador cria volumes
- `provisioner`: define o driver (ex: `kubernetes.io/no-provisioner` para local, `rancher.io/local-path`)
- `reclaimPolicy`: `Retain`, `Delete`, `Recycle` (deprecado)
- `volumeBindingMode`: `Immediate` vs `WaitForFirstConsumer`
- `PersistentVolume (PV)` — recurso de armazenamento real no cluster
- PV pode ser provisionado estaticamente (manual) ou dinamicamente (via StorageClass)

### Exercicios

**1.1 — StorageClass local-path (provisionamento dinamico no lab)**
```bash
# Instalar local-path-provisioner (util em labs sem cloud provider)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl -n local-path-storage get pods
# Definir como StorageClass padrao
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**1.2 — PersistentVolume estatico**
1. Criar diretorio no node: `vagrant ssh master01 -- sudo mkdir -p /mnt/data`.
2. Criar PV manual do tipo `hostPath`:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-lab
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data
  persistentVolumeReclaimPolicy: Retain
```
3. Verificar status: `kubectl get pv pv-lab` — deve estar `Available`.

**1.3 — Inspecionar PVs existentes**
```bash
kubectl get pv -o wide
kubectl describe pv <nome>
# Colunas importantes: CAPACITY, ACCESS MODES, RECLAIM POLICY, STATUS, CLAIM
```

---

## 2. Volume Modes, Access Modes e Reclaim Policies

### Conceitos

**Volume Modes:**
- `Filesystem` (padrao) — montado como diretorio no container
- `Block` — device de bloco bruto (sem filesystem)

**Access Modes:**
| Modo | Sigla | Significado |
|------|-------|-------------|
| ReadWriteOnce | RWO | Montagem leitura+escrita por 1 node |
| ReadOnlyMany | ROX | Montagem somente-leitura por N nodes |
| ReadWriteMany | RWX | Montagem leitura+escrita por N nodes |
| ReadWriteOncePod | RWOP | Montagem por 1 pod (K8s >= 1.22) |

> `hostPath` e `local` suportam apenas `RWO`. NFS e cloud volumes geralmente suportam `RWX`.

**Reclaim Policies:**
- `Retain` — dados preservados apos PVC deletado; PV fica `Released` (requer limpeza manual)
- `Delete` — PV e o volume real sao deletados junto com o PVC
- `Recycle` — deprecado (fazia `rm -rf` no volume)

### Exercicios

**2.1 — Observar comportamento de Retain**
1. Criar PV com `reclaimPolicy: Retain` e bindar via PVC.
2. Deletar o PVC.
3. Observar que PV fica no status `Released` (nao `Available`).
4. Reutilizar o PV: remover o campo `claimRef` e recriar o PVC.

**2.2 — Observar comportamento de Delete**
1. Provisionar PVC usando StorageClass `local-path` (com `reclaimPolicy: Delete`).
2. Deletar o PVC e confirmar que o PV desaparece automaticamente.

**2.3 — Identificar access mode incompativel**
1. Criar PV com `accessModes: [ReadOnlyMany]`.
2. Criar PVC solicitando `ReadWriteOnce`.
3. Observar que o PVC fica em `Pending` (sem match).
4. Corrigir o PVC com o access mode correto.

---

## 3. PersistentVolumeClaim

### Conceitos
- `PVC` — requisicao de armazenamento por namespace
- Binding: Kubernetes encontra PV compativel com capacidade + access modes + storageClass
- `storageClassName: ""` — vincular a PV sem StorageClass
- Status do PVC: `Pending` → `Bound` → (quando deletado) `Terminating`

### Exercicios

**3.1 — Ciclo completo PV + PVC**
1. Criar PV estatico de 500Mi com `accessModes: [ReadWriteOnce]`.
2. Criar PVC solicitando 200Mi (Kubernetes aceita PVs maiores que o solicitado).
3. Confirmar binding: `kubectl get pvc` deve mostrar `Bound`.
4. Deletar PVC e observar status do PV.

**3.2 — PVC com StorageClass dinamico**
1. Criar PVC sem especificar `storageClassName` (usa a StorageClass padrao).
2. Confirmar que o PV foi criado automaticamente.
3. Criar PVC com `storageClassName: local-path` explicitamente e comparar.

**3.3 — Expandir PVC**
> Requer StorageClass com `allowVolumeExpansion: true`.
1. Verificar: `kubectl get storageclass local-path -o yaml | grep allowVolumeExpansion`.
2. Editar o PVC para aumentar a capacidade: `kubectl edit pvc <nome>`.
3. Confirmar expansao: `kubectl describe pvc <nome>`.

---

## 4. Aplicacoes com Armazenamento Persistente

### Conceitos
- Volume montado como `persistentVolumeClaim` no pod spec
- Dados sobrevivem ao ciclo de vida do pod (mas nao necessariamente ao node em hostPath)
- `emptyDir` — volume temporario, deletado com o pod (util para compartilhamento entre containers)
- `configMap` e `secret` como volumes (ver dominio Workloads)

### Exercicios

**4.1 — Pod com PVC montado**
1. Criar PVC de 500Mi.
2. Criar pod com nginx que monta o PVC em `/usr/share/nginx/html`.
3. Escrever arquivo no volume: `kubectl exec <pod> -- sh -c 'echo "Hello PVC" > /usr/share/nginx/html/index.html'`.
4. Deletar o pod.
5. Recriar o pod com o mesmo PVC e verificar que o arquivo ainda existe.

**4.2 — StatefulSet com volumeClaimTemplates**
1. Criar `StatefulSet` com 3 replicas e `volumeClaimTemplates` de 256Mi.
2. Confirmar que foram criados 3 PVCs distintos (`data-<pod>-0`, `data-<pod>-1`, `data-<pod>-2`).
3. Escrever dados distintos em cada pod.
4. Deletar um pod e aguardar recriacao — confirmar que o mesmo PVC e reanexado ao mesmo pod.

**4.3 — emptyDir para compartilhar entre containers**
1. Criar pod multi-container: container `writer` escreve em `/data/log.txt`, container `reader` exibe o arquivo.
2. Ambos montam o mesmo `emptyDir` em `/data`.
3. Verificar que o `reader` ve os dados escritos pelo `writer`.

**4.4 — Diagnosticar PVC em Pending**
Causas comuns a simular:
- `storageClassName` inexistente → criar PVC com `storageClassName: nao-existe`
- Access mode incompativel com PVs disponiveis
- Capacidade solicitada maior que qualquer PV disponivel
- `nodeAffinity` do PV em conflito com o node do pod

Para cada causa:
1. Criar o PVC com o problema.
2. Identificar a causa via: `kubectl describe pvc <nome>` (seção Events).
3. Corrigir e confirmar binding.

---

## Checklist de Dominio

- [ ] Instalar local-path-provisioner e definir StorageClass padrao
- [ ] Criar PV hostPath estatico e bindar via PVC
- [ ] Observar PV em estado Released apos delecao do PVC (Retain)
- [ ] Observar PV deletado automaticamente apos delecao do PVC (Delete)
- [ ] Pod grava dados no PVC, pod e deletado, novo pod relê os mesmos dados
- [ ] StatefulSet com volumeClaimTemplates (3 PVCs distintos)
- [ ] Diagnosticar PVC Pending: storageClass inexistente, access mode errado
