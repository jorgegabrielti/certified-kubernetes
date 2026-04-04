# Sub-tópico 04 — Manage a Highly-Available Kubernetes Cluster

Referência: [CKA Curriculum v1.35](../../CKA_Curriculum_v1.35.pdf)

> **Peso no exame:** Médio — foco em planejamento conceitual e entendimento de topologias. Lab prático limitado por recursos.

---

## Conceitos Fundamentais

### 4.1 Por que Alta Disponibilidade?

Em um cluster single control plane, se o node master falhar:
- A API do Kubernetes fica indisponível
- Novos pods não podem ser agendados
- Workloads existentes continuam rodando, mas sem gerenciamento

Em um cluster **HA (High Availability)**, o control plane é replicado para eliminar esse ponto único de falha.

### 4.2 Componentes que precisam ser redundantes

| Componente | Estratégia HA |
|------------|---------------|
| `kube-apiserver` | Múltiplas réplicas atrás de um load balancer |
| `kube-controller-manager` | Múltiplas réplicas com **leader election** (apenas 1 ativo) |
| `kube-scheduler` | Múltiplas réplicas com **leader election** (apenas 1 ativo) |
| `etcd` | Cluster de N membros com quorum (mínimo 3) |

> **Leader Election:** O controller-manager e o scheduler usam um mecanismo de eleição de líder via etcd/leases. Embora múltiplas réplicas existam, apenas uma processa requisições por vez — as demais ficam em standby.

---

## 5. Topologias de Cluster HA

### 5.1 Stacked etcd (topologia padrão)

Cada control plane node executa **todos** os componentes: apiserver, controller-manager, scheduler **e** etcd.

```
┌─────────────────────────┐   ┌─────────────────────────┐   ┌─────────────────────────┐
│       master01          │   │       master02          │   │       master03          │
│  ┌───────────────────┐  │   │  ┌───────────────────┐  │   │  ┌───────────────────┐  │
│  │   kube-apiserver  │  │   │  │   kube-apiserver  │  │   │  │   kube-apiserver  │  │
│  │  controller-mgr   │  │   │  │  controller-mgr   │  │   │  │  controller-mgr   │  │
│  │    scheduler      │  │   │  │    scheduler      │  │   │  │    scheduler      │  │
│  │      etcd         │◄─┼───┼─►│      etcd         │◄─┼───┼─►│      etcd         │  │
│  └───────────────────┘  │   │  └───────────────────┘  │   │  └───────────────────┘  │
└─────────────────────────┘   └─────────────────────────┘   └─────────────────────────┘
            ▲                              ▲                              ▲
            └──────────────────────────────┴──────────────────────────────┘
                                    Load Balancer
                               (control-plane-endpoint)
```

**Vantagens:** Simples de configurar, menos nodes necessários.  
**Desvantagens:** Falha no node afeta tanto o etcd quanto o control plane.

### 5.2 External etcd (topologia avançada)

O etcd roda em nodes separados e dedicados, independentes dos control plane nodes.

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   master01   │  │   master02   │  │   master03   │     │   etcd01     │  │   etcd02     │  │   etcd03     │
│  apiserver   │  │  apiserver   │  │  apiserver   │◄───►│    etcd      │◄►│    etcd      │◄►│    etcd      │
│  ctrl-mgr    │  │  ctrl-mgr    │  │  ctrl-mgr    │     └──────────────┘  └──────────────┘  └──────────────┘
│  scheduler   │  │  scheduler   │  │  scheduler   │
└──────────────┘  └──────────────┘  └──────────────┘
```

**Vantagens:** Falha em um control plane node não afeta o etcd.  
**Desvantagens:** Requer mais nodes (mínimo 6 para cluster totalmente HA).

---

## 6. Load Balancer para o Control Plane

O `--control-plane-endpoint` define o **DNS/IP virtual** pelo qual todos os clientes (kubectl, kubelet, workers) acessam o apiserver.

```bash
# O endpoint deve ser configurado no kubeadm init ANTES da criação do cluster
kubeadm init \
  --control-plane-endpoint="k8s-api.example.com:6443" \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs
```

> **Importante:** O `--control-plane-endpoint` **não pode ser alterado após a criação do cluster** sem reemitir certificados.

### 6.1 Verificar o endpoint configurado

```bash
# No kubeconfig
kubectl config view | grep server

# No kubeadm config
kubectl get cm kubeadm-config -n kube-system -o yaml | grep controlPlaneEndpoint
```

---

## 7. Adicionando um Segundo Control Plane

O `kubeadm init` com `--upload-certs` armazena os certificados do control plane no cluster por 2 horas.

```bash
# No master01 (durante o init inicial)
kubeadm init \
  --control-plane-endpoint="lb.example.com:6443" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16
```

O output incluirá um comando especial para join de control planes:

```bash
# Executar em master02 e master03
kubeadm join lb.example.com:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <cert-key>
```

---

## 8. etcd e Quorum

O etcd usa o algoritmo **Raft** para consenso. O quorum define o número mínimo de membros necessários para o cluster funcionar.

| Membros etcd | Quorum (mínimo) | Tolerância a falhas |
|:------------:|:---------------:|:-------------------:|
| 1 | 1 | 0 |
| 3 | 2 | **1** |
| 5 | 3 | **2** |
| 7 | 4 | **3** |

**Fórmula:** `quorum = (N / 2) + 1` (arredondado para baixo)

> **Ponto crítico de prova:** Com 3 membros etcd, você pode perder **1** sem interromper o cluster. Com 2 membros restantes, o quorum ainda é atingido (2 ≥ 2).

### 8.1 Verificar membros do etcd

```bash
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --write-out=table
```

### 8.2 Verificar saúde do cluster etcd

```bash
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## 9. Exercícios Práticos

### Conceitual (lab single control plane)

**Ex 4.1 — Mapear os componentes HA**
1. Listar os componentes que precisam ser redundantes num cluster HA (resposta: apiserver, controller-manager, scheduler, etcd).
2. Explicar a diferença entre stacked etcd e external etcd.
3. Calcular: em um cluster com 5 membros etcd, quantas falhas simultâneas são toleradas?

**Ex 4.2 — Inspecionar o endpoint atual**
1. Identificar o endpoint do control plane no kubeconfig: `kubectl config view | grep server`.
2. Verificar o `controlPlaneEndpoint` no ConfigMap do kubeadm: `kubectl get cm kubeadm-config -n kube-system -o yaml`.
3. Identificar o IP do etcd usado pelo apiserver: `grep etcd /etc/kubernetes/manifests/kube-apiserver.yaml`.

**Ex 4.3 — Inspecionar o etcd**
1. Verificar membros: `etcdctl member list` (ver comando completo na seção 8.1).
2. Verificar saúde: `etcdctl endpoint health`.
3. Responder: com 1 membro (lab padrão), qual é o quorum e a tolerância a falhas?

### Avançado (se lab tiver múltiplos masters)

**Ex 4.4 — Simular perda de control plane**
1. Em lab com 3 masters, desligar o master02: `vagrant halt master02`.
2. Verificar que o cluster ainda funciona: `kubectl get nodes`.
3. Verificar que a eleição de líder ocorreu: `kubectl get lease -n kube-system`.
4. Religar master02: `vagrant up master02`.
5. Confirmar que ele rejoint o cluster.

---

## Armadilhas Comuns (Gotchas)

| Erro | Causa | Solução |
|------|-------|---------|
| `--upload-certs` expirado | Certificate key válido por apenas 2h | Regenerar com `kubeadm init phase upload-certs --upload-certs` |
| Load balancer não configurado antes do init | `controlPlaneEndpoint` não pode ser alterado pós-criação | Planejar o endpoint antes do primeiro `kubeadm init` |
| Split-brain no etcd | Número par de membros (sem quorum claro) | Sempre use número ímpar de membros etcd (3, 5, 7) |
| Worker não consegue alcançar LB | Firewalls/Security Groups bloqueando porta 6443 | Verificar conectividade com `nc -zv <lb-ip> 6443` |

---

## Dicas de Prova CKA

- A prova geralmente usa cluster **single control plane** — HA é mais conceitual.
- Conheça a diferença entre **stacked** e **external etcd** com clareza.
- Saiba calcular **quorum** rapidamente: `(N/2) + 1`.
- Memorize as flags do `kubeadm init` para HA: `--control-plane-endpoint` e `--upload-certs`.
- Entenda que `controller-manager` e `scheduler` têm **apenas 1 líder ativo** mesmo com múltiplas réplicas.
