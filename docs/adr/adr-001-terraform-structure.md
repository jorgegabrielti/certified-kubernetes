# ADR-001: Terraform Module Structure for AWS Cluster

**Status:** Accepted  
**Date:** 2026-03-30

---

## Context

The original `IAC/terraform/aws/` implementation had:
- `terraform {}` block and `provider` block mixed in `main.tf` alongside module calls
- Hardcoded subnet IDs and security group IDs in `terraform.tfvars`
- A single `ec2_instances` module called twice (master/worker) with no clear separation
- `file()` for user_data scripts — no variable injection possible
- No VPC module — all network resources were expected to be pre-existing
- Variables without `type` or `validation` blocks

This made the code non-reproducible (different accounts/regions would fail), hard to extend, and inconsistent with Terraform community conventions.

---

## Comparison

| Concern | Old approach | New approach |
|---------|-------------|-------------|
| Provider config | Mixed in `main.tf` | `versions.tf` only |
| Network | Pre-existing (hardcoded IDs) | `module.vpc` creates from scratch |
| Security group | Pre-existing (hardcoded ID) | `module.security_groups` creates |
| Variable validation | None | `validation {}` blocks on all inputs |
| User_data injection | `file()` — static | `templatefile()` — variables from Terraform |
| Naming | Hardcoded strings | `locals.name_prefix` + `locals.common_tags` |
| Workers | Single module call | `count = var.worker_count` |
| Outputs | None | IPs, SSH commands, join instructions |
| K8s version | Hardcoded in `.sh` files | `var.k8s_version`, injected via template |

---

## Decision

Adopt a layered module structure:

1. **`versions.tf`** — owns `terraform {}`, `required_providers`, optional `backend`
2. **`main.tf`** — owns module calls only (no `resource` blocks at root)
3. **`locals.tf`** — owns `name_prefix` and `common_tags`
4. **`variables.tf`** — all inputs, all with `type` + `description` + `validation`
5. **`outputs.tf`** — all user-facing outputs with `description`
6. **`modules/vpc`** — creates VPC, public subnet, IGW, and route table
7. **`modules/security_groups`** — creates the shared K8s SG with individual rule resources
8. **`modules/ec2_instances`** — parameterized EC2 with `count`, `templatefile()` user_data
9. **`modules/ec2_instances/templates/*.tpl`** — bash scripts as Terraform templates

---

## Consequences

**Positive:**
- Fully reproducible in any AWS account/region — zero pre-existing dependencies
- K8s version change = single variable update, no script edits
- `terraform destroy` cleans up everything — no orphaned resources
- Validation blocks catch bad inputs at `terraform plan` time
- `locals.common_tags` ensures consistent tagging across all resources

**Negative:**
- More files to maintain than a flat structure
- First-time contributors must understand the module composition pattern
- `association` between route table and subnet is a new "invisible" resource

**Neutral:**
- Old `.sh` files in `modules/ec2_instances/` are superseded by `.tpl` files — they remain for historical reference but are not used
