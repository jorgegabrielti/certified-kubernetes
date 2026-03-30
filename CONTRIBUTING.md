# Contributing Guide

Este documento descreve o workflow de desenvolvimento, convenções e como contribuir com melhorias ao projeto.

---

## Pré-requisitos

| Ferramenta | Versão mínima | Verificação |
|------------|---------------|-------------|
| Terraform  | >= 1.7.0      | `terraform version` |
| AWS CLI    | >= 2.0        | `aws --version` |
| Git        | qualquer      | `git --version` |

Além disso:
- **AWS profile `terraform`** configurado via `aws configure --profile terraform`
- **Key pair `cka-keypair`** criado na região `us-east-1` na conta AWS alvo

---

## Workflow de Desenvolvimento

Todo trabalho segue o fluxo **spec-first**:

```
1. Spec  →  2. ADR (se houver breaking change)  →  3. Implementação  →  4. Validação
```

### 1. Escreva a spec

Para qualquer nova feature ou alteração de comportamento, crie ou atualize o arquivo de spec correspondente em `docs/specs/`:

```
docs/specs/feature-<nome>.md
```

A spec deve ter critérios de aceitação numerados (AC-1, AC-2, …) antes de qualquer implementação começar.

### 2. ADR (Architecture Decision Record)

Se a mudança alterar a estrutura de módulos, outputs públicos, ou topologia de rede, crie um ADR em:

```
docs/adr/adr-NNN-<slug>.md
```

Consulte `docs/adr/adr-001-terraform-structure.md` como referência de formato.

### 3. Implemente

Siga as convenções detalhadas nas skills disponíveis (ver abaixo). Todo novo recurso Terraform deve:

- Residir dentro de um módulo (`modules/<nome>/`)
- Expor variáveis com `description` e `validation` quando aplicável
- Usar `locals.common_tags` para todos os recursos com tag support
- **Nunca** definir resources no root — apenas chamadas de módulo

### 4. Valide

Sempre execute a sequência completa antes de propor qualquer mudança:

```bash
cd IAC/terraform/aws
terraform init
terraform validate
terraform fmt -recursive
terraform plan
```

Todos os comandos devem terminar sem erros antes de considerar a implementação completa.

---

## Como Adicionar uma Variável Terraform

1. Declare em `IAC/terraform/aws/variables.tf` com `type`, `description`, `default` e `validation` (quando aplicável)
2. Adicione o valor concreto em `terraform.tfvars`
3. Passe a variável para os módulos relevantes em `main.tf`
4. Declare como input em `modules/<nome>/variables.tf`
5. Execute `terraform validate` e `terraform fmt`

> Consulte o skill **terraform-aws** em `.github/skills/terraform-aws/SKILL.md` para convenções detalhadas.

---

## Como Modificar Scripts de Provisionamento

Os scripts de bootstrap são **templates Terraform** (`.tpl`), não scripts bash diretos:

```
IAC/terraform/aws/modules/ec2_instances/templates/
├── userDataMaster.sh.tpl
└── userDataWorker.sh.tpl
```

Regras obrigatórias:
- Variáveis Terraform: `${k8s_version}`, `${pod_network_cidr}` (sem escaping)
- Variáveis bash: sempre escapadas como `$${VAR}` (dois cifrões)
- **Nunca** usar `${VAR:+expr}` ou `${VAR:-default}` bash expansions — o parser Terraform não suporta
- IMDSv2 obrigatório para obter IPs privados (não use IMDSv1)
- Todo processo de bootstrap deve logar em `/var/log/k8s-<role>-init.log`

> Consulte o skill **k8s-provisioning** em `.github/skills/k8s-provisioning/SKILL.md` para o fluxo completo.

---

## Como Modificar as Regras de Security Group

Regras são declaradas como recursos individuais `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` — **nunca** como blocos inline no `aws_security_group`.

Local: `IAC/terraform/aws/modules/security_groups/main.tf`

Para adicionar uma nova porta:
1. Adicione um novo resource `aws_vpc_security_group_ingress_rule` com nome descritivo
2. Documente a justificativa no comentário do resource
3. Atualize a tabela SG em `docs/architecture.md`

---

## Ciclo de Vida do Cluster

### Subir o cluster

```bash
cd IAC/terraform/aws
terraform apply
```

### Conectar ao master

```bash
terraform output ssh_master
# Copie e execute o comando SSH retornado
```

### Executar o join dos workers

```bash
# No master:
cat /root/kubeadm-join.sh
# Copie o comando kubeadm join e execute em cada worker
```

### Destruir o cluster

```bash
terraform destroy
```

> Sempre destrua o ambiente ao terminar os estudos para evitar custos desnecessários na AWS.

---

## Convenções de Commit

Use mensagens no formato **Conventional Commits**:

```
feat: adiciona suporte a múltiplos node pools
fix: corrige CIDR da subnet pública
docs: atualiza diagrama de topologia em architecture.md
chore: atualiza provider hashicorp/aws para 5.95.0
```

| Prefixo  | Quando usar |
|----------|-------------|
| `feat`   | Nova feature ou recurso Terraform |
| `fix`    | Correção de bug |
| `docs`   | Apenas documentação |
| `chore`  | Manutenção, deps, CI |
| `refactor` | Refatoração sem mudança de comportamento |

---

## Assistência com IA

Este repositório está configurado para GitHub Copilot e Claude Code. Consulte:

| Recurso | Localização | Quando usar |
|---------|-------------|-------------|
| Copilot instructions | `.github/copilot-instructions.md` | Carregado automaticamente no VS Code |
| Skill: Terraform AWS | `.github/skills/terraform-aws/SKILL.md` | Ao modificar qualquer arquivo `.tf` |
| Skill: K8s Provisioning | `.github/skills/k8s-provisioning/SKILL.md` | Ao modificar templates `.tpl` |
| Agent: infra-review | `.github/agents/infra-review.agent.md` | Revisão antes de `terraform apply` |
| Prompt: upgrade-k8s | `.github/prompts/upgrade-k8s.prompt.md` | Atualizar versão do Kubernetes |
| Prompt: add-worker | `.github/prompts/add-worker.prompt.md` | Adicionar nós workers |
| AGENTS.md (root) | `AGENTS.md` | Visão geral dos agentes e regras |

---

## O que NÃO está no escopo deste projeto

- Autoscaling (ASG / Karpenter)
- Load Balancer externo (ALB/NLB)
- Cluster gerenciado (EKS)
- Ingress Controller
- Persistent Volumes (EBS/EFS)
- Gerenciamento de certificados TLS
- Monitoramento (Prometheus/Grafana)

Para estudar esses tópicos, crie uma spec em `docs/specs/` antes de iniciar qualquer implementação.
