# Certified Kubernetes Administrator (CKA) — Studies

Ambiente de estudo prático para a certificação **CKA (Certified Kubernetes Administrator)**.

Provisiona um cluster Kubernetes vanilla (kubeadm + Cilium) na **AWS EC2 via Terraform** — totalmente reproduzível e destruível com um único comando. O ambiente **VirtualBox/Vagrant** original está mantido para quem preferir estudar offline.

---

## Stack

| Componente   | Versão / Tecnologia          |
|--------------|------------------------------|
| Kubernetes   | v1.31                        |
| Bootstrap    | kubeadm                      |
| CRI          | containerd                   |
| CNI          | Cilium                       |
| Instâncias   | AWS EC2 t3.medium            |
| OS           | Ubuntu 22.04 LTS (us-east-1) |
| IaC          | Terraform >= 1.7.0           |
| AWS Provider | hashicorp/aws = 5.94.1       |

---

## Pré-requisitos

- **Terraform** >= 1.7.0 instalado
- **AWS CLI** configurado com perfil `terraform`
- **Key pair** `cka-keypair` criado na região `us-east-1`
- Conta AWS com permissões para EC2 e VPC

```bash
aws configure --profile terraform
```

---

## Quickstart — AWS (EC2)

```bash
# 1. Acesse o diretório Terraform
cd IAC/terraform/aws

# 2. Inicialize os providers
terraform init

# 3. Valide a configuração
terraform validate

# 4. Visualize o plano (18 recursos)
terraform plan

# 5. Provisione o cluster
terraform apply
```

### Conectar e configurar o join

```bash
# Conectar ao master
ssh -i ~/.ssh/cka-keypair.pem ubuntu@$(terraform output -raw master_public_ip)

# No master: executar o join nos workers
cat /root/kubeadm-join.sh
# Copie e execute o comando em cada worker node
```

### Outputs disponíveis pós-apply

```bash
terraform output ssh_master       # Comando SSH para o master
terraform output ssh_workers      # Comandos SSH para os workers
terraform output join_instruction # Passo a passo do join
```

### Destruir o ambiente

```bash
terraform destroy
```

> Sempre destrua o ambiente ao terminar os estudos para evitar custos desnecessários na AWS.

---

## Quickstart — Local (VirtualBox)

```bash
cd IAC/Vagrant
vagrant up
vagrant ssh master
```

> Requer Vagrant + VirtualBox instalados localmente.

---

## Estrutura do Repositório

```
certified-kubernetes/
├── AGENTS.md                         # Guia para Claude Code e agentes AI
├── CONTRIBUTING.md                   # Guia de contribuição e workflow
├── IAC/
│   ├── terraform/aws/                # Ambiente AWS (principal)
│   │   ├── versions.tf               # Bloco terraform + provider pinado
│   │   ├── main.tf                   # Composição dos módulos
│   │   ├── locals.tf                 # name_prefix e common_tags
│   │   ├── variables.tf              # Todas as variáveis com validações
│   │   ├── outputs.tf                # IPs, SSH commands, join instruction
│   │   ├── terraform.tfvars          # Valores padrão do projeto
│   │   └── modules/
│   │       ├── vpc/                  # VPC, subnet, IGW, route table
│   │       ├── security_groups/      # SG com regras individuais
│   │       └── ec2_instances/        # Instâncias EC2 + templates userdata
│   │           └── templates/
│   │               ├── userDataMaster.sh.tpl
│   │               └── userDataWorker.sh.tpl
│   └── Vagrant/                      # Ambiente local (VirtualBox)
│       ├── Vagrantfile
│       ├── conf/
│       └── provision/
├── Study/                            # Material de estudo (aulas e tutoriais)
│   ├── aulas/                        # Aulas por dia (dia 1 → aulas 1-9)
│   ├── Howto/                        # Scripts e procedimentos úteis
│   └── Tutorial/                     # Tutoriais passo a passo
├── CKA/                              # Conteúdo específico CKA
├── CKAD/                             # Conteúdo específico CKAD
├── CKS/                              # Conteúdo específico CKS
├── docs/
│   ├── architecture.md               # Diagrama, módulos, decisões
│   ├── specs/                        # Especificações de features
│   └── adr/                          # Architecture Decision Records
└── .github/
    ├── copilot-instructions.md       # Instruções para GitHub Copilot
    ├── skills/                       # Skills on-demand para AI
    ├── agents/                       # Agentes especializados
    └── prompts/                      # Prompts parametrizados
```

---

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [docs/architecture.md](docs/architecture.md) | Topologia, módulos Terraform, SG rules, bootstrap flow |
| [docs/specs/feature-vanilla-cluster-aws.md](docs/specs/feature-vanilla-cluster-aws.md) | Requisitos e critérios de aceitação |
| [docs/adr/adr-001-terraform-structure.md](docs/adr/adr-001-terraform-structure.md) | Decisão sobre estrutura modular |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Como contribuir e workflow de desenvolvimento |
| [AGENTS.md](AGENTS.md) | Guia de uso com Claude Code e GitHub Copilot |

---

## Topologia do Cluster

```
Internet
    │
    ▼
 [IGW] ── VPC 10.0.0.0/16
    │
    ▼
Subnet Pública 10.0.1.0/24 (us-east-1a)
    │
    ├── master   (t3.medium) ← kubeadm init + Cilium CNI
    ├── worker01 (t3.medium) ← join manual
    └── worker02 (t3.medium) ← join manual
        Pod CIDR: 10.244.0.0/16
```

---

## Variáveis Configuráveis

Edite `terraform.tfvars` para sobrescrever os valores padrão.

| Variável        | Padrão        | Descrição                         |
|-----------------|---------------|-----------------------------------|
| `worker_count`  | `2`           | Número de workers (1–5)           |
| `instance_type` | `t3.medium`   | Tipo de instância EC2             |
| `k8s_version`   | `v1.31`       | Versão do Kubernetes              |
| `aws_region`    | `us-east-1`   | Região AWS                        |
| `aws_profile`   | `terraform`   | AWS CLI profile                   |
| `key_name`      | `cka-keypair` | Nome do key pair no AWS           |

---

## Licença

Distribuído sob a licença MIT. Consulte o arquivo [LICENSE](LICENSE) para detalhes.
