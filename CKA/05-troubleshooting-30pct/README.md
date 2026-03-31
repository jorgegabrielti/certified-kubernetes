# Troubleshooting — 30%

Referencia: [CKA Curriculum v1.35](../CKA_Curriculum_v1.35.pdf)

> Este e o dominio de maior peso na prova (30%). Exige velocidade e metodo.
> Treine com um roteiro fixo: **observar → localizar → corrigir → validar**.

---

## Sub-topicos

| # | Topico | Peso estimado |
|---|--------|---------------|
| 1 | Evaluate cluster and node logging | Alto |
| 2 | Understand how to monitor applications | Alto |
| 3 | Manage container stdout & stderr logs | Alto |
| 4 | Troubleshoot application failure | Alto |
| 5 | Troubleshoot cluster component failure | Alto |
| 6 | Troubleshoot networking | Alto |

---

## Roteiro Geral de Diagnostico

```
1. kubectl get nodes          → nodes prontos?
2. kubectl get pods -A        → pods em CrashLoop, Pending, Error?
3. kubectl describe pod <pod> → Events + State + Conditions
4. kubectl logs <pod>         → stderr/stdout do container
5. kubectl logs <pod> --previous → crash anterior
6. journalctl -u kubelet      → kubelet no node com problema
7. kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

## 1. Logs do Cluster e dos Nodes

### Conceitos
- `journalctl` — sistema de logs do systemd (kubelet, containerd)
- `kubectl logs` — stdout/stderr dos containers
- `/var/log/pods/` e `/var/log/containers/` — arquivos de log no node
- Logs dos componentes estaticos: `kubectl logs -n kube-system kube-apiserver-master01`

### Exercicios

**1.1 — Inspecionar logs do kubelet**
```bash
# Via vagrant ssh master01
sudo journalctl -u kubelet -f             # logs em tempo real
sudo journalctl -u kubelet --since "10 min ago"
sudo journalctl -u kubelet | grep -i error
```

**1.2 — Inspecionar logs dos componentes do control plane**
```bash
kubectl logs -n kube-system kube-apiserver-master01
kubectl logs -n kube-system kube-controller-manager-master01
kubectl logs -n kube-system kube-scheduler-master01
kubectl logs -n kube-system etcd-master01
```

**1.3 — Logs direto no filesystem do node**
```bash
sudo ls /var/log/pods/
sudo ls /var/log/containers/
# Encontrar log de pod especifico
sudo tail -f /var/log/pods/<namespace>_<pod-name>_<uid>/<container>/0.log
```

---

## 2. Monitoramento de Aplicacoes

### Conceitos
- `kubectl top pods` / `kubectl top nodes` — requer metrics-server
- `kubectl get events` — historico de eventos do cluster
- `kubectl describe` — estado detalhado de qualquer recurso
- Probes: `livenessProbe`, `readinessProbe` como sinais de saude

### Exercicios

**2.1 — Instalar e usar metrics-server**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Se TLS der problema no lab, adicionar flag:
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top nodes
kubectl top pods -A
```

**2.2 — Identificar pod consumindo mais recursos**
```bash
kubectl top pods -A --sort-by=cpu | head -5
kubectl top pods -A --sort-by=memory | head -5
```

**2.3 — Eventos do namespace**
```bash
kubectl get events -n default --sort-by='.lastTimestamp'
kubectl get events -A --field-selector reason=OOMKilling
kubectl get events -A --field-selector reason=BackOff
```

---

## 3. Logs de Containers (stdout/stderr)

### Conceitos
- `kubectl logs <pod>` — log do container principal
- `kubectl logs <pod> -c <container>` — container especifico em pod multi-container
- `kubectl logs <pod> --previous` — log do container antes do restart
- `kubectl logs <pod> -f` — streaming em tempo real
- `kubectl logs <pod> --tail=50` — ultimas N linhas

### Exercicios

**3.1 — Log de container com crash**
1. Criar pod com comando que falha depois de 5 segundos:
```yaml
command: ["sh", "-c", "sleep 5; exit 1"]
```
2. Aguardar CrashLoopBackOff.
3. Ver logs do crash atual: `kubectl logs <pod>`.
4. Ver logs do crash anterior: `kubectl logs <pod> --previous`.
5. Contar restarts: `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].restartCount}'`.

**3.2 — Log de pod multi-container**
1. Criar pod com dois containers: `main` (nginx) e `sidecar` (busybox logando data a cada 1s).
2. Ver log do sidecar: `kubectl logs <pod> -c sidecar`.
3. Confirmar que `kubectl logs <pod>` sem `-c` mostra o container principal.

**3.3 — Streaming de logs durante deploy**
```bash
kubectl logs -f deployment/my-app --all-containers=true
```

---

## 4. Troubleshooting de Aplicacao

### Conceitos
- Pod nao inicia: imagem errada, repositorio inacessivel, OOM, probe failing
- Pod CrashLoopBackOff: aplicacao crasha, init container falha, comando errado
- Pod Pending: sem recursos, NodeSelector/Affinity nao satisfeito, PVC nao bound
- Pod Running mas sem trafego: Service selector errado, container port errado, probe failing readiness

### Exercicios

**4.1 — Imagem inexistente**
1. Criar pod com imagem `nginx:nao-existe-version`.
2. Observar status `ErrImagePull` → `ImagePullBackOff`.
3. Corrigir a imagem: `kubectl set image pod/<pod> nginx=nginx:latest`.

**4.2 — CrashLoopBackOff por comando errado**
1. Criar pod com `command: ["nao-existe"]`.
2. Observar CrashLoopBackOff.
3. Ver logs: `kubectl logs <pod> --previous`.
4. Corrigir editando o pod (deletar e recriar com o comando certo).

**4.3 — Pod Pending por falta de recursos**
1. Criar pod com `requests.cpu: 100` (100 CPUs — impossivel de satisfazer).
2. Observar Pending e evento `Insufficient cpu`.
3. Corrigir para `100m` e confirmar scheduling.

**4.4 — Pod Pending por NodeSelector invalido**
1. Criar pod com `nodeSelector: disktype: ssd`.
2. Observar Pending e evento `0/2 nodes are available: 2 node(s) didn't match Pod's node affinity`.
3. Adicionar a label ao node: `kubectl label node worker01 disktype=ssd`.
4. Confirmar scheduling.

**4.5 — Aplicacao sem trafego (Service selector errado)**
1. Criar `Deployment` com label `app: frontend`.
2. Criar `Service` com `selector: app: backend` (errado).
3. Confirmar: `kubectl get endpoints <service>` mostra vazio.
4. Corrigir o selector e validar endpoints.

**4.6 — readinessProbe falhando**
1. Criar Deployment com `readinessProbe` HTTP em `/ready` (rota inexistente).
2. Observar que os pods ficam `Running` mas `0/1 Ready`.
3. Confirmar que o Service nao direciona trafego.
4. Corrigir a probe para `/` e validar que o pod fica `1/1 Ready`.

---

## 5. Troubleshooting de Componentes do Cluster

### Conceitos
- Componentes do control plane: `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `etcd`
- No lab kubeadm: todos sao static pods em `/etc/kubernetes/manifests/`
- Erro num manifesto → static pod nao sobe → componente indisponivel
- kubelet e um servico systemd (nao e pod)
- containerd e o CRI (gerencia pull e execucao de containers)

### Exercicios

**5.1 — Quebrar e recuperar o kube-scheduler**
1. Mover o manifesto do scheduler para fora: `sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/`.
2. Criar um novo pod — ele ficara `Pending` (sem scheduler).
3. Restaurar o manifesto: `sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/`.
4. Aguardar o pod ser agendado.

**5.2 — Quebrar e recuperar o kube-controller-manager**
1. Editar o manifesto e introduzir uma flag invalida: `--invalid-flag=true`.
2. Aguardar o pod reiniciar e falhar.
3. Observar que `Deployments` param de criar novos pods.
4. Corrigir o manifesto e validar.

**5.3 — kubelet parado no worker**
```bash
# Via vagrant ssh worker01
sudo systemctl stop kubelet
# De volta ao host: observar node NotReady
kubectl get nodes -w
# Reiniciar kubelet
vagrant ssh worker01 -c "sudo systemctl start kubelet"
```
1. Cronometrar quanto tempo leva para o node aparecer como `NotReady`.
2. Identificar os eventos gerados: `kubectl describe node worker01`.
3. Reiniciar o kubelet e cronometrar o retorno a `Ready`.

**5.4 — Problema na configuracao do kubelet**
1. No worker01, editar `/var/lib/kubelet/config.yaml` e introduzir yaml invalido.
2. Reiniciar kubelet: `sudo systemctl restart kubelet`.
3. Confirmar falha: `sudo systemctl status kubelet` e `sudo journalctl -u kubelet -n 50`.
4. Corrigir o arquivo e reiniciar.

**5.5 — etcd indisponivel**
1. Parar o etcd movendo o manifesto: `sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/`.
2. Observar que o apiserver passa a retornar erros na API.
3. Restaurar o manifesto e aguardar recuperacao.

---

## 6. Troubleshooting de Networking

### Conceitos
- Pod nao consegue falar com outro pod: CNI com problema, NetworkPolicy bloqueando
- Pod nao resolve DNS: CoreDNS com problema, dnsPolicy errada
- Service inacessivel: selector errado, porta errada, kube-proxy com problema
- Node sem rede: interface CNI down, rota faltando

### Exercicios

**6.1 — DNS quebrado no pod**
1. Escalar CoreDNS para 0: `kubectl scale deployment coredns -n kube-system --replicas=0`.
2. Criar pod de teste e verificar que DNS falha: `kubectl exec dns-test -- nslookup kubernetes`.
3. Restaurar CoreDNS para 2 replicas e validar.

**6.2 — NetworkPolicy bloqueando trafego**
1. Criar namespace `restricted` com `NetworkPolicy` que bloqueia todo ingress:
```yaml
spec:
  podSelector: {}
  policyTypes: [Ingress]
```
2. Subir pod nginx em `restricted` e tentar acessar de outro namespace — falha esperada.
3. Criar `NetworkPolicy` que permite ingress de namespace especifico.
4. Validar que o trafego e permitido apenas do namespace correto.

**6.3 — Service com porta errada**
1. Criar `Deployment` nginx expondo `containerPort: 80`.
2. Criar `Service` com `targetPort: 8080` (errado).
3. Confirmar que `curl` no ClusterIP falha com reset de conexao.
4. Corrigir `targetPort: 80` e validar.

**6.4 — Pod sem IP / CNI com problema**
1. Inspecionar pod preso em `ContainerCreating` com evento `failed to set up sandbox`:
```bash
kubectl describe pod <pod>  # evento: "network plugin is not ready"
kubectl -n kube-system describe pod cilium-<id>
```
2. Verificar configuracao CNI: `ls /etc/cni/net.d/ && ls /opt/cni/bin/`.
3. Restartar o DaemonSet do CNI: `kubectl rollout restart daemonset/cilium -n kube-system`.

**6.5 — Diagnostico completo de conectividade (cenario de prova)**
Sequencia para diagnosticar "Pod A nao consegue falar com Pod B":
```bash
# 1. Pods com IP?
kubectl get pods -o wide

# 2. Endpoints do servico?
kubectl get endpoints <service>

# 3. NetworkPolicy bloqueia?
kubectl get networkpolicies -A

# 4. DNS resolve?
kubectl exec pod-a -- nslookup <service>

# 5. Ping direto por IP?
kubectl exec pod-a -- ping -c 2 <IP-pod-b>

# 6. Porta responde?
kubectl exec pod-a -- nc -zv <IP-pod-b> 80

# 7. kube-proxy saudavel?
kubectl -n kube-system get pods -l k8s-app=kube-proxy

# 8. CNI saudavel?
kubectl -n kube-system get pods -l k8s-app=cilium
```

---

## Simulados de Troubleshooting Cronometrado

### Cenario A — Cluster Quebrado (meta: 15 min)
> Setup: execute os comandos de "quebra" ANTES de comecar o cronometro.

**Quebras para introduzir:**
```bash
# 1. Parar kubelet no worker
vagrant ssh worker01 -c "sudo systemctl stop kubelet"
# 2. Colocar scheduler com flag invalida
vagrant ssh master01 -c "sudo sed -i 's/--leader-elect=true/--leader-elect=invalid/' /etc/kubernetes/manifests/kube-scheduler.yaml"
# 3. Service com selector errado
kubectl patch svc nginx-svc -p '{"spec":{"selector":{"app":"wrong-label"}}}'
```

**Tarefa:** Diagnosticar e corrigir todas as falhas sem dicas adicionais.

### Cenario B — Aplicacao Degradada (meta: 10 min)
**Quebras para introduzir:**
```bash
# 1. Imagem errada num Deployment
kubectl set image deployment/my-app my-app=nginx:nao-existe
# 2. readinessProbe na rota errada
kubectl patch deployment my-app --patch '{"spec":{"template":{"spec":{"containers":[{"name":"my-app","readinessProbe":{"httpGet":{"path":"/fail","port":80}}}]}}}}'
# 3. PVC em Pending
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-pvc
spec:
  storageClassName: nao-existe
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
```

**Tarefa:** Identificar e corrigir cada falha.

---

## Checklist de Dominio

- [ ] Inspecionar logs do kubelet com `journalctl`
- [ ] Logs dos 4 componentes do control plane
- [ ] Diagnosticar e resolver pod CrashLoopBackOff
- [ ] Diagnosticar e resolver pod Pending (recursos, nodeSelector, PVC)
- [ ] Diagnosticar e resolver Service sem endpoints (selector errado)
- [ ] Quebrar e recuperar kube-scheduler
- [ ] Parar e reiniciar kubelet no worker, observar NotReady
- [ ] DNS quebrado (CoreDNS scaled to 0) e recuperado
- [ ] NetworkPolicy bloqueando trafego e liberado
- [ ] Completar Cenario A cronometrado em < 15 min
