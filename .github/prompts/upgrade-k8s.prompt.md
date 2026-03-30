---
name: upgrade-k8s
description: "Upgrade the Kubernetes version in the CKA study cluster. Updates k8s_version in terraform.tfvars and validates the change."
---

# Upgrade Kubernetes Version

Upgrade the Kubernetes version used by the cluster.

## Input

Current version: [CURRENT_VERSION]
Target version:  [TARGET_VERSION]

(Example: from `v1.31` to `v1.32`)

## Steps

1. **Load the terraform-aws skill** to follow all Terraform conventions.

2. **Update `terraform.tfvars`**: change `k8s_version` from `[CURRENT_VERSION]` to `[TARGET_VERSION]`.

3. **Verify the new version exists** in the Kubernetes apt repository:
   ```
   https://pkgs.k8s.io/core:/stable:/[TARGET_VERSION]/deb/
   ```

4. **Run validation**:
   ```bash
   terraform validate
   terraform fmt -check -recursive
   terraform plan
   ```

5. **Confirm plan output**: both `module.ec2_master` and `module.ec2_workers` instances should show `user_data` hash change (replacement). Expected: `1 destroy + 1 create` for master, `2 destroy + 2 create` for workers.

6. **Check `docs/architecture.md`**: update the K8s version reference if present.

7. **Report** the plan summary and confirm the change is safe to apply.

## Acceptance Criteria

- [ ] `k8s_version` updated in `terraform.tfvars`
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows user_data hash changes for all 3 instances
- [ ] No unexpected resource replacements (only EC2 instances should change)
- [ ] Architecture doc updated if it references the version
