---
name: add-worker
description: "Add a new worker node to the CKA study cluster. Updates worker_count in terraform.tfvars, validates the change, and provides the manual join procedure."
---

# Add Worker Node

Increase the number of worker nodes in the cluster.

## Input

Current worker count: [CURRENT_COUNT]
New worker count:     [NEW_COUNT]

## Steps

1. **Load the terraform-aws skill** to follow all Terraform conventions.

2. **Validate the new count** is within the allowed range (1–5, per variable validation).

3. **Update `terraform.tfvars`**: change `worker_count` from `[CURRENT_COUNT]` to `[NEW_COUNT]`.

4. **Run validation**:
   ```bash
   terraform validate
   terraform fmt -check -recursive
   terraform plan
   ```

5. **Confirm plan output**: should show exactly `[NEW_COUNT - CURRENT_COUNT]` new EC2 instance(s) to add. No existing resources should be replaced or destroyed.

6. **After apply**, provide the join procedure:
   ```
   1. Wait ~3 minutes for new worker(s) to finish provisioning
   2. SSH into master:       ssh -i ~/.ssh/<key>.pem ubuntu@<master_public_ip>
   3. Get join command:      sudo cat /root/kubeadm-join.sh
   4. SSH into new worker:   ssh -i ~/.ssh/<key>.pem ubuntu@<new_worker_ip>
   5. Run as root:           sudo <join_command>
   6. Verify from master:    kubectl get nodes
   ```

7. **Report** the worker IPs from `terraform output worker_public_ips`.

## Acceptance Criteria

- [ ] `worker_count` updated in `terraform.tfvars`
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows only additive changes (no replacements)
- [ ] New worker count within 1–5 range
- [ ] Join procedure provided with correct IPs from outputs
