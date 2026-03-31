# Services and Networking — 20%

Referencia: [CKA Curriculum v1.35](../CKA_Curriculum_v1.35.pdf)

---

## Sub-topicos

| # | Topico | Peso estimado |
|---|--------|---------------|
| 1 | Understand host networking configuration on the cluster nodes | Medio |
| 2 | Understand connectivity between Pods | Alto |
| 3 | Understand ClusterIP, NodePort, LoadBalancer service types and endpoints | Alto |
| 4 | Know how to use Ingress controllers and Ingress resources | Alto |
| 5 | Know how to configure and use CoreDNS | Medio |
| 6 | Choose an appropriate container network interface plugin | Medio |

---

## 1. Networking nos Nodes

### Conceitos
- Interfaces de rede do node: `eth0`, CNI bridge interface (`cni0`, `cilium_*`)
- Rotas IP: `ip route`, `ip addr`
- `iptables` ou `ipvs` como backend do kube-proxy
- Portas reservadas pelo Kubernetes: 6443 (apiserver), 2379-2380 (etcd), 10250 (kubelet), 10259 (scheduler), 10257 (controller-manager)
- Portas do NodePort: 30000-32767

### Exercicios

**1.1 — Inspecionar rede do node**
```bash
# No master01 via vagrant ssh master01
ip addr show
ip route
# Identificar a interface usada para a rede do pod
ip addr show cni0 2>/dev/null || ip addr show cilium_host 2>/dev/null
```

**1.2 — Verificar kube-proxy mode**
```bash
kubectl -n kube-system get configmap kube-proxy -o yaml | grep mode
# Ou inspecionar regras iptables
sudo iptables -t nat -L KUBE-SERVICES | head -20
```

**1.3 — Confirmar portas abertas no control plane**
```bash
sudo ss -tlnp | grep -E '6443|2379|10250|10259|10257'
```

---

## 2. Conectividade entre Pods

### Conceitos
- Todo pod recebe um IP unico roteavel dentro do cluster
- Pods no mesmo namespace comunicam-se diretamente por IP ou nome de servico
- Pods em namespaces diferentes: apenas por servico (salvo NetworkPolicy aberta)
- CNI e responsavel por programar as rotas entre nodes

### Exercicios

**2.1 — Comunicacao direta entre pods**
1. Criar dois pods no mesmo namespace: `pod-a` e `pod-b` com `busybox`.
2. Obter IP do `pod-b`: `kubectl get pod pod-b -o wide`.
3. Testar conectividade: `kubectl exec pod-a -- wget -q -O- http://<IP-pod-b>`.

**2.2 — Comunicacao entre namespaces**
1. Criar namespace `ns-a` e `ns-b`.
2. Subir um pod com nginx em `ns-a` exposto por um `ClusterIP` Service.
3. A partir de um pod em `ns-b`, acessar o servico usando o FQDN: `<service>.<namespace>.svc.cluster.local`.

**2.3 — Diagnosticar Pod sem conectividade**
1. Criar pod com `hostNetwork: true` e observar que o IP e o do node.
2. Identificar a diferenca de comportamento no DNS e nas portas.
3. Criar pod com porta inexistente no container e diagnosticar a falha de conexao.

---

## 3. Tipos de Service

### Conceitos
- `ClusterIP` — acessivel apenas dentro do cluster (padrao)
- `NodePort` — expoe a porta em todos os nodes (`30000-32767`)
- `LoadBalancer` — provisiona LB externo (requer cloud provider ou MetalLB)
- `ExternalName` — alias para FQDN externo
- `Endpoints` — lista de IPs que o Service envia trafego
- `selector` ausente no Service = gerenciamento manual de Endpoints

### Exercicios

**3.1 — ClusterIP**
1. Criar `Deployment` com nginx (3 replicas) e `Service` do tipo `ClusterIP`.
2. Confirmar que o ClusterIP e acessivel a partir de outro pod: `curl http://<ClusterIP>`.
3. Inspecionar endpoints: `kubectl get endpoints <service>` — deve listar os 3 pods.
4. Escalar para 5 e verificar que os Endpoints foram atualizados automaticamente.

**3.2 — NodePort**
1. Criar `Service` do tipo `NodePort` para o mesmo nginx.
2. Identificar a porta alocada: `kubectl get svc nginx-svc -o jsonpath='{.spec.ports[0].nodePort}'`.
3. Acessar pelo IP do node: `curl http://192.168.1.100:<nodePort>`.
4. Entender por que o trafego chega mesmo sem acertar o node que hospeda o pod.

**3.3 — Service sem selector (Endpoints manuais)**
1. Criar `Service` sem `selector`.
2. Criar `Endpoints` manual apontando para um IP externo ou pod especifico.
3. Acessar o servico e confirmar que o trafego chega ao IP configurado manualmente.

**3.4 — Diagnosticar Service inoperante**
1. Criar `Deployment` e `Service` com `selector` errado (label inexistente).
2. Observar `kubectl get endpoints` com lista vazia.
3. Corrigir o selector e validar reconexao.

---

## 4. Ingress

### Conceitos
- `Ingress` — regra de roteamento HTTP/HTTPS (Layer 7)
- `IngressClass` — referencia ao controller responsavel
- Ingress Controller (ex: nginx-ingress, Traefik) — nao instalado por padrao
- `pathType`: `Prefix`, `Exact`, `ImplementationSpecific`
- TLS: referencia a `Secret` do tipo `kubernetes.io/tls`

### Exercicios

**4.1 — Instalar Ingress Controller (nginx)**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.0/deploy/static/provider/baremetal/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

**4.2 — Ingress com path-based routing**
1. Criar dois `Deployments` e `Services`: `app-v1` (ClusterIP :80) e `app-v2` (ClusterIP :80).
2. Criar `Ingress` que encaminha `/v1` para `app-v1` e `/v2` para `app-v2`.
3. Testar: `curl http://<NodeIP>:<IngressNodePort>/v1` e `/v2`.

**4.3 — Ingress com host-based routing**
1. Criar `Ingress` com `rules[].host: app.local`.
2. Adicionar entrada no `/etc/hosts` do host Windows: `192.168.1.100  app.local`.
3. Acessar `http://app.local:<NodePort>` e confirmar roteamento.

**4.4 — Ingress com TLS**
1. Gerar certificado autoassinado: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=app.local"`.
2. Criar Secret TLS: `kubectl create secret tls app-tls --cert=tls.crt --key=tls.key`.
3. Configurar `Ingress` com bloco `tls` referenciando o secret.
4. Testar: `curl -k https://app.local:<NodePort>`.

---

## 5. CoreDNS

### Conceitos
- CoreDNS e o DNS padrao do Kubernetes desde v1.11
- FQDN: `<service>.<namespace>.svc.cluster.local`
- ConfigMap `coredns` no namespace `kube-system`
- `ndots:5` no `resolv.conf` do pod
- `dnsPolicy`: `ClusterFirst`, `Default`, `None`, `ClusterFirstWithHostNet`

### Exercicios

**5.1 — Inspecionar CoreDNS**
```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system get configmap coredns -o yaml
kubectl -n kube-system logs -l k8s-app=kube-dns
```

**5.2 — Resolucao DNS dentro de pods**
1. Criar pod `dns-test` com imagem `busybox` (comando `sleep 3600`).
2. Resolver nome de servico por nome curto, namespace e FQDN:
```bash
kubectl exec dns-test -- nslookup kubernetes
kubectl exec dns-test -- nslookup kubernetes.default
kubectl exec dns-test -- nslookup kubernetes.default.svc.cluster.local
```
3. Verificar o `resolv.conf` do pod: `kubectl exec dns-test -- cat /etc/resolv.conf`.

**5.3 — Stub zone customizada no CoreDNS**
1. Editar o `ConfigMap` do CoreDNS para adicionar um `stub zone` que encaminha `internal.local` para um DNS especifico.
2. Restartar o CoreDNS: `kubectl rollout restart deployment/coredns -n kube-system`.
3. Testar resolucao do dominio customizado.

---

## 6. CNI Plugin

### Conceitos
- CNI (Container Network Interface) — padrao de plugins de rede
- Plugins comuns no CKA: Cilium, Flannel, Calico, Weave
- Instalado apos `kubeadm init`, antes dos nodes ficarem `Ready`
- Arquivos de configuracao: `/etc/cni/net.d/`
- Binarios: `/opt/cni/bin/`

### Exercicios

**6.1 — Inspecionar CNI instalado**
```bash
# No master01
ls /etc/cni/net.d/
ls /opt/cni/bin/
kubectl -n kube-system get pods -l k8s-app=cilium
```

**6.2 — Reinstalar CNI (Flannel como alternativa)**
> Apenas em lab descartavel — implica destruir e recriar o cluster.
1. Fazer `kubeadm init` com `--pod-network-cidr=10.244.0.0/16`.
2. Instalar Flannel: `kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml`.
3. Confirmar nodes `Ready` com Flannel.

---

## Checklist de Dominio

- [ ] Inspecionar interfaces de rede e portas abertas no control plane
- [ ] Pod-to-pod ping dentro e entre namespaces
- [ ] Criar Service ClusterIP e confirmar endpoints automaticos
- [ ] Criar Service NodePort e acessar pelo IP do node
- [ ] Diagnosticar Service com selector errado (endpoints vazios)
- [ ] Instalar Ingress Controller e criar regra path-based
- [ ] Resolver FQDN de servico com `nslookup` dentro de um pod
- [ ] Inspecionar ConfigMap do CoreDNS e logs
