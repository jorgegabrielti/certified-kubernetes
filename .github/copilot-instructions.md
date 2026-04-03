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

## CKA/CKAD/CKS Content Authoring

### Topic folder structure (mandatory pattern)
Every certification domain topic follows this layout — do NOT deviate:

```
CKA/<NN>-<slug>-<weight>pct/
├── README.md                          ← index, sub-topic table, commands, armadilhas, checklist
├── article-01-<slug>.md               ← in-depth article (concept + production context)
├── article-02-<slug>.md
└── <NN>-<sub-topic-slug>/
    ├── README.md                      ← concept, manifests, exercises (4–6 per sub-topic)
    └── *.yaml                         ← practice manifests (valid, runnable)
```

### Documentation rules
- Every YAML in a sub-topic folder must be syntactically valid and deployable on a vanilla kind or kubeadm cluster
- README.md at sub-topic level must include: concept summary, manifest listing, 4–6 exercises with expected output
- Article files are deep-dives — include production context, common gotchas, and kubectl command cheatsheet
- Main README.md table links to subfolder paths (`./01-<slug>/`), not `#anchor` links

### YAML exercise rules
- Always use explicit `apiVersion` and `kind`
- `spec.containers[].command` (not `commands`)
- ConfigMap `items[]` requires both `key` and `path`
- `env[].name` is required — never leave it empty
- Test YAML against an actual cluster before committing
- Volume name in `spec.volumes[]` must match `spec.containers[].volumeMounts[].name` exactly

### Spec-first for new topics
New CKA/CKAD/CKS topic documentation starts with a spec in `docs/specs/feature-<name>.md`.
Use `docs/specs/spec-template.md` as the starting point.

## Skills Available

ALWAYS load the relevant skill before modifying these areas:
- **Terraform files** → `.github/skills/terraform-aws/SKILL.md`
- **Provisioning `.tpl` scripts** → `.github/skills/k8s-provisioning/SKILL.md`
- **CKA/CKAD/CKS topic documentation** → `.github/skills/cka-topic-documentation/SKILL.md`
- **Kubernetes YAML exercises** → `.github/skills/k8s-yaml-exercises/SKILL.md`
