# Architecture — CKA Studies Cluster

**Last updated:** 2026-03-30  
**K8s version:** v1.31  
**CNI:** Cilium  
**IaC:** Terraform ≥ 1.7 / AWS provider 5.94.x

---

## Overview

A vanilla Kubernetes cluster deployed on AWS EC2 using `kubeadm` for bootstrapping and Cilium as the CNI plugin. Infrastructure is fully managed by Terraform — create with `terraform apply`, destroy with `terraform destroy`. No persistent state outside of Terraform.

```
Internet
    │
    ▼
┌──────────────────────────────────────────────┐
│  AWS Region: us-east-1                       │
│                                              │
│  VPC: 10.0.0.0/16                           │
│  ┌─────────────────────────────────────────┐ │
│  │  Public Subnet: 10.0.1.0/24 (us-east-1a)│ │
│  │                                         │ │
│  │  ┌─────────────────────┐                │ │
│  │  │  master             │                │ │
│  │  │  t3.medium          │                │ │
│  │  │  cka-studies-dev-   │                │ │
│  │  │  master             │                │ │
│  │  │  • kube-apiserver   │                │ │
│  │  │  • etcd             │                │ │
│  │  │  • controller-mgr   │                │ │
│  │  │  • scheduler        │                │ │
│  │  │  • cilium           │                │ │
│  │  └─────────────────────┘                │ │
│  │                                         │ │
│  │  ┌───────────────┐ ┌───────────────┐    │ │
│  │  │  worker01     │ │  worker02     │    │ │
│  │  │  t3.medium    │ │  t3.medium    │    │ │
│  │  │  • kubelet    │ │  • kubelet    │    │ │
│  │  │  • containerd │ │  • containerd │    │ │
│  │  │  • cilium     │ │  • cilium     │    │ │
│  │  └───────────────┘ └───────────────┘    │ │
│  └─────────────────────────────────────────┘ │
│                                              │
│  Internet Gateway → Route Table              │
└──────────────────────────────────────────────┘
```

---

## Terraform Module Structure

```
IAC/terraform/aws/
├── versions.tf          → terraform{} + required_providers + optional backend
├── main.tf              → module calls only
├── locals.tf            → name_prefix, common_tags
├── variables.tf         → all inputs with validation
├── outputs.tf           → IPs, SSH commands, join instructions
├── terraform.tfvars     → runtime values
└── modules/
    ├── vpc/             → VPC, subnet, IGW, route table, RT association
    ├── security_groups/ → 1 SG + individual rule resources
    └── ec2_instances/   → aws_instance (count), gp3 volume, public IP
        └── templates/
            ├── userDataMaster.sh.tpl
            └── userDataWorker.sh.tpl
```

### Module dependency chain

```
vpc → security_groups → ec2_instances (master)
vpc → security_groups → ec2_instances (workers)
```

---

## Network Design

| Resource | CIDR / Value |
|----------|-------------|
| VPC | 10.0.0.0/16 |
| Public subnet | 10.0.1.0/24 |
| Pod network (Cilium) | 10.244.0.0/16 |
| API server port | 6443 |

All nodes are in the same public subnet with individual public IPs. No NAT gateway — direct internet access via IGW. Appropriate for study, not production.

---

## Security Group Rules

One shared SG for all nodes (`cka-studies-dev-k8s-sg`):

| Direction | Port | Source | Purpose |
|-----------|------|--------|---------|
| Inbound | 22 | 0.0.0.0/0 | SSH admin access |
| Inbound | 6443 | 0.0.0.0/0 | Kubernetes API server |
| Inbound | 2379-2380 | self | etcd (internal) |
| Inbound | 10250 | self | kubelet API |
| Inbound | 10257 | self | kube-controller-manager |
| Inbound | 10259 | self | kube-scheduler |
| Inbound | 30000-32767 | 0.0.0.0/0 | NodePort services |
| Inbound | all | self | Cilium overlay + internal traffic |
| Outbound | all | 0.0.0.0/0 | Internet access |

---

## Bootstrap Flow

### Master (`userDataMaster.sh.tpl`)
1. Disable swap, install dependencies
2. Load `overlay` + `br_netfilter` kernel modules
3. Apply sysctl for K8s networking
4. Install and configure `containerd` (`SystemdCgroup = true`)
5. Install `kubelet`, `kubeadm`, `kubectl` (version-locked via apt-mark hold)
6. Get private IP via **IMDSv2**
7. `kubeadm init --apiserver-advertise-address=<private_ip> --pod-network-cidr=10.244.0.0/16`
8. Copy kubeconfig → `/home/ubuntu/.kube/config`
9. Install Cilium CLI, run `cilium install`
10. Save join command → `/root/kubeadm-join.sh` (chmod 600)

### Workers (`userDataWorker.sh.tpl`)
Steps 1–6 identical to master. No `kubeadm join` — join is manual.

### Worker Join (manual)
```bash
# From master:
sudo cat /root/kubeadm-join.sh

# On each worker (as root):
sudo kubeadm join <master_private_ip>:6443 --token ... --discovery-token-ca-cert-hash ...
```

---

## Key Design Decisions

| Decision | Record |
|----------|--------|
| Terraform module structure | [ADR-001](adr/adr-001-terraform-structure.md) |
| Cilium as CNI | Chosen for eBPF performance and CKA exam relevance |
| Manual worker join | Avoids race conditions with token TTL |
| Public subnet (no NAT) | Simplicity for study environment |
| templatefile() over file() | Variables injected at plan time |

---

## Out of Scope (v1)

- EKS or managed K8s
- HA control plane (multiple masters)
- Ingress controller / cert-manager
- Persistent volumes (EBS CSI)
- CI/CD pipelines
- Password-protected or private cluster endpoints
