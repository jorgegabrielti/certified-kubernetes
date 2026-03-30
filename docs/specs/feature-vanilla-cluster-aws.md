# Feature Spec: Vanilla Kubernetes Cluster on AWS (EC2 + Terraform)

**Status:** Accepted  
**Date:** 2026-03-30  
**Author:** Jorge Gabriel

---

## 1. Context and Motivation

The original `cka-studies` environment used Vagrant + VirtualBox for local cluster provisioning. While functional offline, local VMs consume significant hardware resources, require VirtualBox installation, and cannot be shared or reproduced in cloud environments.

For CKA exam preparation, practitioners benefit from working against a real cloud cluster — exercising cloud-native networking, EC2 instance metadata, IAM, and real kubeadm flows. Terraform enables deterministic, team-shareable, rapidly-destroyable infrastructure via a single `terraform apply/destroy` cycle.

---

## 2. Functional Requirements

**FR1.** The system SHALL provision exactly 1 control-plane node and a configurable number of worker nodes (default: 2, range: 1–5) on AWS EC2.

**FR2.** All infrastructure (VPC, subnets, IGW, route tables, security groups, EC2 instances) SHALL be created and destroyed exclusively via Terraform.

**FR3.** The master node SHALL bootstrap a Kubernetes cluster using `kubeadm init` with Cilium as the CNI plugin.

**FR4.** Worker nodes SHALL install all Kubernetes prerequisites via user_data and wait for a manual `kubeadm join` command.

**FR5.** The master node SHALL save the `kubeadm join` command to `/root/kubeadm-join.sh` with permissions `600`.

**FR6.** `terraform output` SHALL expose the master public IP, worker public IPs, ready-to-use SSH commands, and a textual join procedure.

**FR7.** The Kubernetes version SHALL be configurable via a single `k8s_version` variable (format: `vMAJOR.MINOR`) without modifying any script files.

**FR8.** All provisioning output SHALL be logged to `/var/log/k8s-<role>-init.log` on each instance.

---

## 3. Non-Functional Requirements

**NFR1.** The Terraform code SHALL follow the module structure defined in `docs/architecture.md`: `versions.tf`, `main.tf`, `locals.tf`, `variables.tf`, `outputs.tf`.

**NFR2.** Provider versions SHALL be pinned exactly (e.g., `= 5.94.1`), not with fuzzy constraints.

**NFR3.** Instance metadata SHALL be retrieved via IMDSv2 (token-based) — IMDSv1 is forbidden.

**NFR4.** No AWS credentials, subnet IDs, or SG IDs SHALL be hardcoded in any `*.tf` file outside of `terraform.tfvars`.

**NFR5.** `terraform.tfstate` and `terraform.tfstate.backup` SHALL be excluded from version control via `.gitignore`.

**NFR6.** The full cluster (3 nodes) SHALL reach `Ready` state within 10 minutes of `terraform apply` completion (excluding manual join steps).

---

## 4. Acceptance Criteria

**AC1.** Given a configured AWS CLI profile `terraform` and an existing EC2 key pair `cka-keypair`, when `terraform apply` is run, then it SHALL complete with exit code 0 and create exactly 18 resources (5 VPC-related, 9 SG-related, 3 EC2, 1 RT association).

**AC2.** Given `terraform apply` has completed, when `terraform output` is run, then it SHALL display `master_public_ip`, `worker_public_ips` (list of 2), `ssh_master`, `ssh_workers`, and `join_instruction` — all with non-empty values.

**AC3.** Given 5 minutes have elapsed since apply, when the user SSHes into the master and runs `kubectl get nodes`, then the master node SHALL appear with status `Ready`.

**AC4.** Given the master is Ready, when the user SSHes into each worker and runs the content of `/root/kubeadm-join.sh` as root, then each worker SHALL become `Ready` within 3 minutes.

**AC5.** Given all 3 nodes are Ready, when `kubectl get pods -n kube-system` is run, then all Cilium pods SHALL be in `Running` state.

**AC6.** Given a running cluster, when `k8s_version` in `terraform.tfvars` is changed to a new minor version and `terraform apply` is re-run, then all 3 EC2 instances SHALL be replaced and the new Kubernetes version SHALL be installed.

**AC7.** Given the cluster is no longer needed, when `terraform destroy -auto-approve` is run, then it SHALL complete with exit code 0 and return 0 remaining resources.

**AC8.** Given `terraform validate` is run after any code change, then it SHALL return `Success! The configuration is valid.`

---

## 5. Known Risks and Limitations

- **Token TTL:** `kubeadm join` tokens expire after 24 hours. If the worker join is delayed beyond that, a new token must be generated on the master (`kubeadm token create --print-join-command`).
- **Public subnet:** All nodes have public IPs. Port 22 is open to the internet. Acceptable for ephemeral study clusters; not suitable for production.
- **Single AZ:** All resources are in `us-east-1a`. No high availability.
- **No persistent storage:** EBS volumes are deleted on instance termination. Cluster state is ephemeral.
- **IMDSv2 dependency:** Instances must support IMDSv2 (all current AWS AMIs do). The metadata endpoint is not accessible outside EC2.

---

## 6. Impact on Tests

Manual validation checklist (no automated tests for infrastructure):

- `terraform validate` — syntax and reference check
- `terraform fmt -check -recursive` — formatting check
- `terraform plan` — resource count assertion (18 to add)
- Post-apply: `kubectl get nodes`, `kubectl get pods -n kube-system`
- Post-destroy: zero resources remaining
