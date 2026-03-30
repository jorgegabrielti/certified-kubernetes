---
name: terraform-aws
description: "Use this skill when modifying, adding, or reviewing any Terraform file in IAC/terraform/aws/. Covers module structure, variable conventions, templatefile usage, security group rules, and the validate/fmt workflow."
---

# Skill: terraform-aws

## When this skill applies

Trigger phrases: **terraform**, **IAC**, **ec2**, **vpc**, **security group**, **modules**, **variables.tf**, **outputs.tf**, **userdata**, **apply**, **plan**, **destroy**, `*.tf`, `*.tpl`.

---

## Repository Layout

```
IAC/terraform/aws/
├── versions.tf        ← ONLY place for: terraform{}, required_providers, backend
├── main.tf            ← ONLY module calls (no resource blocks)
├── locals.tf          ← name_prefix, common_tags
├── variables.tf       ← all input vars with type + description + validation
├── outputs.tf         ← exposed values (IPs, SSH commands, join instructions)
├── terraform.tfvars   ← non-secret runtime values
└── modules/
    ├── vpc/           ← VPC + subnet + IGW + route table + RT association
    ├── security_groups/ ← 1 SG + individual ingress/egress rule resources
    └── ec2_instances/ ← aws_instance with count, public IP, gp3 root volume
        └── templates/ ← userDataMaster.sh.tpl, userDataWorker.sh.tpl
```

Each module has exactly: `main.tf`, `variables.tf`, `outputs.tf`.

---

## Non-Negotiable Conventions

| Rule | Why |
|------|-----|
| `versions.tf` owns `terraform {}` | Prevents duplicate blocks |
| `main.tf` = module calls only | Easy to see the full topology at a glance |
| `locals.tf` owns tags and name prefix | Single place to change naming convention |
| All variables have `validation {}` | Fail fast with clear messages |
| `templatefile()` — never `file()` | Variables injected at plan time, not runtime |
| `$${}` for bash `${}` inside `.tpl` | Avoids Terraform template parse errors |
| `associate_public_ip_address = true` | Instances need public IPs in this public subnet setup |
| `gp3` root volume, `delete_on_termination = true` | Cost and cleanup hygiene |
| Module outputs only — no `module.x.aws_resource.y.attr` | Encapsulation |

---

## Adding a New Variable

1. Add to `variables.tf` with `type`, `description`, and `validation` block
2. If it affects a template, add it to the `templatefile()` call in `main.tf`
3. Add a default in `terraform.tfvars` with a comment
4. If removing or renaming an existing variable → create an ADR

```hcl
variable "example" {
  description = "Clear description of what this controls."
  type        = string
  default     = "value"

  validation {
    condition     = length(var.example) > 0
    error_message = "example must not be empty."
  }
}
```

---

## Adding a New Module

1. Create `modules/<name>/main.tf`, `variables.tf`, `outputs.tf`
2. Wire it in root `main.tf` under a clear comment block
3. Expose only what other modules need in `outputs.tf`
4. Add outputs to root `outputs.tf` if end-user-facing

---

## Security Group Rules

Use `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (not inline `ingress` blocks). Self-referencing rules use `referenced_security_group_id = aws_security_group.k8s.id`.

Open ports for the cluster:

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | 0.0.0.0/0 | SSH |
| 6443 | TCP | 0.0.0.0/0 | kube-apiserver |
| 2379-2380 | TCP | self | etcd |
| 10250 | TCP | self | kubelet |
| 10257 | TCP | self | kube-controller-manager |
| 10259 | TCP | self | kube-scheduler |
| 30000-32767 | TCP | 0.0.0.0/0 | NodePort |
| all | all | self | Cilium overlay |

---

## Validation Checklist

Run after every change:

```bash
terraform fmt -recursive        # Format all .tf files
terraform validate              # Syntax + reference check
terraform plan                  # Confirm expected resource delta
```

Expected plan for a clean apply: **18 resources** (5 VPC, 9 SG, 3 EC2, 1 RT association).

---

## Template Files (.tpl)

- Located at `modules/ec2_instances/templates/`
- Variables passed via `templatefile()` in root `main.tf`
- Current variables:
  - `userDataMaster.sh.tpl`: `k8s_version`, `pod_network_cidr`
  - `userDataWorker.sh.tpl`: `k8s_version`
- Bash `${VAR}` → must be written as `$${VAR}` inside `.tpl`
- Terraform variables in template → written as `${var_name}` (no escaping)

---

## Common Pitfalls (Learned)

- `${VAR:+expr}` bash conditional expansion **breaks** Terraform template parsing — use an `if/else` block instead
- Old `.sh` files in `modules/ec2_instances/` are legacy (replaced by `.tpl`) — do not reference them
- `aws_internet_gateway` must be in the same module as the VPC — not at root level
