# CKA Studies — Copilot Instructions

## Project Context

Hands-on CKA study environment. Vanilla Kubernetes cluster on AWS EC2 provisioned by Terraform.
Stack: Terraform ≥ 1.7, AWS provider 5.94.x, Ubuntu 22.04, K8s v1.31, Cilium CNI, kubeadm.

## Always-On Rules

### Terraform conventions
- `versions.tf` owns the `terraform {}` block exclusively
- `main.tf` contains only module calls — no `resource` blocks at root
- `locals.tf` owns `name_prefix` and `common_tags` — never repeat tag values in resources
- All variables have `type`, `description`, and `validation` blocks where applicable
- Module outputs are the only way to reference a module's resources — never use `module.x.resource.y.attr`
- `templatefile()` for all user_data — never `file()`
- Run `terraform validate` + `terraform fmt -recursive` after every change

### Bash templates (`.tpl` files)
- Escape bash variable syntax as `$${}` inside `.tpl` when it would conflict with Terraform interpolation
- Always use IMDSv2 (token + metadata HTTP calls) — never `curl 169.254.169.254` without token header
- No `netplan` or `enp0s8` — VirtualBox-only constructs
- Workers never run `kubeadm join` automatically

### Security
- Never commit `*.tfstate`, `*.tfstate.backup`, or `*.tfplan`
- No hardcoded AWS account IDs, subnet IDs, or SG IDs outside of `terraform.tfvars`
- Path traversal not applicable here, but never `chmod 777` on sensitive files (e.g., kubeconfig)

### Spec-first
- Every new Terraform variable, module, or provisioning feature starts with a spec under `docs/specs/`
- Architecture changes update `docs/architecture.md`
- Breaking changes (removed/renamed variable, changed output) create a new `docs/adr/adr-NNN-<slug>.md`

## Skills Available

ALWAYS load the relevant skill before modifying these areas:
- **Terraform files** → `.github/skills/terraform-aws/SKILL.md`
- **Provisioning `.tpl` scripts** → `.github/skills/k8s-provisioning/SKILL.md`
