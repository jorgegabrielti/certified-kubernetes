# AGENTS.md — Certified Kubernetes Administrator Studies

This file guides AI coding agents (Claude Code, GitHub Copilot, Cursor, etc.) working in this repository.

---

## Project Overview

This repository is a hands-on study environment for the **CKA (Certified Kubernetes Administrator)** certification. It provides a reproducible vanilla Kubernetes cluster (kubeadm + Cilium CNI) built on AWS EC2 via Terraform.

**Topology:** 1 control-plane master + 2 worker nodes  
**OS:** Ubuntu 22.04 LTS  
**K8s:** v1.31  
**CNI:** Cilium  
**IaC:** Terraform ≥ 1.7 / AWS provider 5.94.x  

---

## Repository Structure

```
certified-kubernetes/
├── IAC/
│   ├── terraform/aws/          ← Terraform entrypoint (see terraform-aws skill)
│   │   ├── versions.tf         ← terraform block + provider versions (pinned)
│   │   ├── main.tf             ← module composition only
│   │   ├── locals.tf           ← name_prefix, common_tags
│   │   ├── variables.tf        ← all input variables with validation blocks
│   │   ├── outputs.tf          ← IPs, SSH commands, join instructions
│   │   ├── terraform.tfvars    ← non-secret values
│   │   └── modules/
│   │       ├── vpc/            ← VPC, subnet, IGW, route table
│   │       ├── security_groups/← K8s port rules (self-ref for internal traffic)
│   │       └── ec2_instances/  ← EC2 with count, public IP, gp3 volume
│   │           └── templates/  ← userDataMaster.sh.tpl, userDataWorker.sh.tpl
│   └── Vagrant/                ← Local dev with VirtualBox (legacy)
├── CKA/                        ← CKA practice tracks and curriculum
├── CKAD/                       ← CKAD practice tracks and curriculum
├── CKS/                        ← CKS practice tracks and curriculum
├── docs/
│   ├── architecture.md
│   ├── specs/
│   └── adr/
├── .github/
│   ├── copilot-instructions.md
│   ├── skills/
│   ├── agents/
│   └── prompts/
└── CONTRIBUTING.md
```

---

## Mandatory Rules for AI Agents

### Terraform
- **Never** hardcode AWS resource IDs (subnet IDs, SG IDs) — always use module outputs
- **Always** use `templatefile()` for user_data scripts, never `file()`
- **Always** escape bash `${}` patterns as `$${}` inside `.tpl` files to avoid Terraform template conflicts
- `versions.tf` owns the `terraform {}` block — never duplicate it in `main.tf`
- `main.tf` contains only module calls — no resource blocks at root level
- Run `terraform validate` and `terraform fmt -recursive` after every change
- Lock file `.terraform.lock.hcl` **must be committed**

### Provisioning scripts (`.tpl` files)
- Use IMDSv2 (two-step: token request → metadata request) — never IMDSv1
- Never use `netplan`/`enp0s8` configuration — those are VirtualBox-specific
- The master saves the join command to `/root/kubeadm-join.sh` (chmod 600)
- Workers do NOT run `kubeadm join` automatically — join is always manual
- Log all provisioning output to `/var/log/k8s-*-init.log`

### Security
- Never log or expose AWS credentials
- Never commit `.tfstate`, `.tfstate.backup`, or `.tfplan` files
- SSH inbound (port 22) is open to 0.0.0.0/0 for study purposes — note this in any review

### Spec-first
- New features start with a spec in `docs/specs/feature-<name>.md`
- Architecture changes require updating `docs/architecture.md`
- Breaking changes (variable renames, output removals) require a new ADR in `docs/adr/`

---

## CKA/CKAD/CKS Content Rules

### Topic documentation
- Every domain topic follows the folder pattern: `CKA/<NN>-<slug>-<weight>pct/`
- Each sub-topic is a numbered subfolder (`NN-<slug>/`) with its own `README.md`
- YAML manifests live inside the sub-topic folder — never at the topic root
- Every YAML file must be referenced in the sub-topic `README.md` under **Manifests**

### YAML correctness (non-negotiable)
- Use `command:` (singular) — never `commands:`
- `env[].name` is required — never empty
- `configMap.items[].path` is required when `items[]` is specified
- Volume names must match `volumeMounts[].name` exactly
- Always dry-run: `kubectl apply --dry-run=server -f <file.yaml>` before committing

### Spec-first for new topics
New CKA/CKAD/CKS domain documentation starts with a spec in `docs/specs/feature-<name>.md`.
Use `docs/specs/spec-template.md`. Implementation begins only after numbered acceptance criteria exist.

---

## Available Skills

Load these skills before working on the corresponding area:

| Skill | File | Trigger |
|-------|------|---------|
| `terraform-aws` | `.github/skills/terraform-aws/SKILL.md` | Any `*.tf` file |
| `k8s-provisioning` | `.github/skills/k8s-provisioning/SKILL.md` | Any `*.tpl` provision script |
| `cka-topic-documentation` | `.github/skills/cka-topic-documentation/SKILL.md` | Creating/updating topic READMEs and articles |
| `k8s-yaml-exercises` | `.github/skills/k8s-yaml-exercises/SKILL.md` | Writing or reviewing YAML manifests |

---

## Available Agents

| Agent | File | Use When |
|-------|------|----------|
| `infra-review` | `.github/agents/infra-review.agent.md` | Before `terraform apply` — full IaC review |
| `cka-content-review` | `.github/agents/cka-content-review.agent.md` | Before marking a topic done — content quality review |
| `exercise-generator` | `.github/agents/exercise-generator.agent.md` | Generating exam-style practice exercises |

---

## Workflow for Common Tasks

### Upgrading Kubernetes version
Use the prompt: `.github/prompts/upgrade-k8s.prompt.md`

### Adding a worker node
Use the prompt: `.github/prompts/add-worker.prompt.md`

### Scaffolding a new CKA/CKAD/CKS topic
Use the prompt: `.github/prompts/new-cka-topic.prompt.md`

### Generating exercises for a sub-topic
Use the prompt: `.github/prompts/generate-exercises.prompt.md`

### Infrastructure review before apply
Use the agent: `.github/agents/infra-review.agent.md`

### Reviewing CKA documentation quality
Use the agent: `.github/agents/cka-content-review.agent.md`

---

## Out of Scope

Do NOT add these without a spec and ADR:
- EKS or managed Kubernetes
- Helm chart management
- Multi-region or HA control plane
- Ingress controllers or cert-manager
- CI/CD pipelines inside the cluster
