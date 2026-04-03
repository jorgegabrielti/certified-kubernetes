# SKILLS.md — AI Skills Catalog

This file documents all available skills in `.github/skills/`. Skills are domain-specific knowledge packages that AI agents load before working in a particular area.

**How to use:** In your prompt or conversation, reference the relevant skill by name. The AI will load the SKILL.md file before making changes.

---

## Available Skills

| Skill | Trigger | File |
|-------|---------|------|
| [`terraform-aws`](#terraform-aws) | Modifying any `*.tf` file under `IAC/terraform/aws/` | [SKILL.md](.github/skills/terraform-aws/SKILL.md) |
| [`k8s-provisioning`](#k8s-provisioning) | Modifying `*.tpl` provisioning scripts | [SKILL.md](.github/skills/k8s-provisioning/SKILL.md) |
| [`cka-topic-documentation`](#cka-topic-documentation) | Creating or updating CKA/CKAD/CKS topic docs | [SKILL.md](.github/skills/cka-topic-documentation/SKILL.md) |
| [`k8s-yaml-exercises`](#k8s-yaml-exercises) | Writing or reviewing Kubernetes YAML manifests | [SKILL.md](.github/skills/k8s-yaml-exercises/SKILL.md) |

---

## Skill Details

### terraform-aws

**Applies to:** All `*.tf` files and `*.tfvars` files under `IAC/terraform/aws/`

**What it covers:**
- Module structure rules (`versions.tf`, `main.tf`, `locals.tf`, `variables.tf`, `outputs.tf`)
- Variable conventions with `validation {}` blocks
- `templatefile()` vs `file()` — when to use each
- Security group and EC2 conventions
- `terraform validate` + `terraform fmt -recursive` workflow
- Adding new variables, modules, or outputs

**When NOT needed:** Reading Terraform files for context only (no edits).

---

### k8s-provisioning

**Applies to:** `IAC/terraform/aws/modules/ec2_instances/templates/*.tpl`

**What it covers:**
- IMDSv2 mandatory pattern (token + metadata)
- Bash `${}` escaping as `$${}` inside `.tpl` files
- Master bootstrap flow (kubeadm init, Cilium install, join command export)
- Worker bootstrap flow (prerequisites only — no auto-join)
- containerd + SystemdCgroup configuration
- Logging all output to `/var/log/k8s-*-init.log`

**When NOT needed:** Reading scripts for context only (no edits).

---

### cka-topic-documentation

**Applies to:** Any file under `CKA/`, `CKAD/`, or `CKS/` — README files, article files, sub-topic folder creation

**What it covers:**
- Canonical folder structure: `NN-slug-weightpct/` → `NN-slug/` → `README.md + *.yaml`
- Topic root README.md sections (sub-topic table, commands, armadilhas, checklist)
- Sub-topic README.md sections (Conceito, Manifests, Comandos úteis, Exercícios)
- Article file structure (TL;DR, Conceito, Configuração, Armadilhas, Referências)
- Naming conventions for folders, articles, and YAML files
- Checklist for marking a topic complete

**When NOT needed:** Reading documentation for context only (no structural changes).

---

### k8s-yaml-exercises

**Applies to:** Any `*.yaml` file under `CKA/`, `CKAD/`, or `CKS/`

**What it covers:**
- `apiVersion` + `kind` quick reference matrix
- `command:` (not `commands:`) — most common mistake
- `env[].name` required — never empty
- `configMap.items[].path` required when `items[]` specified
- Volume name ↔ `volumeMounts[].name` must match exactly
- Immutable Pod fields + `kubectl replace --force` workflow
- Probe patterns (`livenessProbe`, `readinessProbe`, `startupProbe`)
- Validation workflow: `kubectl apply --dry-run=server`
- CKA exam speed tips: imperative manifest generation

**When NOT needed:** Reading YAML files for context only (no edits).

---

## Available Agents

| Agent | Use When | File |
|-------|---------|------|
| `infra-review` | Before `terraform apply` | [infra-review.agent.md](.github/agents/infra-review.agent.md) |
| `cka-content-review` | Before marking a CKA topic done | [cka-content-review.agent.md](.github/agents/cka-content-review.agent.md) |
| `exercise-generator` | Generating practice exercises | [exercise-generator.agent.md](.github/agents/exercise-generator.agent.md) |

## Available Prompts

| Prompt | Use When | File |
|--------|---------|------|
| `new-cka-topic` | Scaffolding a new certification topic | [new-cka-topic.prompt.md](.github/prompts/new-cka-topic.prompt.md) |
| `generate-exercises` | Adding exercises to a sub-topic | [generate-exercises.prompt.md](.github/prompts/generate-exercises.prompt.md) |
| `add-worker` | Adding a worker node to the cluster | [add-worker.prompt.md](.github/prompts/add-worker.prompt.md) |
| `upgrade-k8s` | Upgrading the Kubernetes version | [upgrade-k8s.prompt.md](.github/prompts/upgrade-k8s.prompt.md) |
