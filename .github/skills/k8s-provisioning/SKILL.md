---
name: k8s-provisioning
description: "Use this skill when modifying, reviewing, or debugging the Kubernetes provisioning scripts in IAC/terraform/aws/modules/ec2_instances/templates/. Covers IMDSv2 usage, kubeadm init/join flow, containerd config, Cilium install, and the master/worker split."
---

# Skill: k8s-provisioning

## When this skill applies

Trigger phrases: **userdata**, **provision**, **kubeadm**, **containerd**, **cilium**, **kubelet**, **join command**, **bootstrap**, `userDataMaster.sh.tpl`, `userDataWorker.sh.tpl`.

---

## File Locations

```
IAC/terraform/aws/modules/ec2_instances/templates/
├── userDataMaster.sh.tpl   ← control-plane bootstrap
└── userDataWorker.sh.tpl   ← worker prerequisites only (no join)
```

These are Terraform `templatefile()` templates. All bash `${}` must be escaped as `$${}`. Terraform variables are written as `${var_name}`.

---

## Master Bootstrap Flow (`userDataMaster.sh.tpl`)

1. Disable swap (`swapoff -a` + remove from `/etc/fstab`)
2. Install base dependencies (`apt-transport-https`, `ca-certificates`, `curl`, `pgp`)
3. Load kernel modules: `overlay`, `br_netfilter`
4. Apply sysctl settings for Kubernetes networking
5. Install and configure `containerd` (with `SystemdCgroup = true`)
6. Add Kubernetes `${k8s_version}` apt repository and install `kubelet`, `kubeadm`, `kubectl`
7. `apt-mark hold` all three packages
8. Get private IP via **IMDSv2** (see IMDSv2 section below)
9. Set `KUBELET_EXTRA_ARGS=--node-ip=<PRIVATE_IP>` in `/etc/default/kubelet`
10. `kubeadm init --apiserver-advertise-address=<PRIVATE_IP> --pod-network-cidr=${pod_network_cidr}`
11. Copy kubeconfig to `/home/ubuntu/.kube/config`
12. Install Cilium CLI and run `cilium install`
13. Generate join command → save to `/root/kubeadm-join.sh` (chmod 600)
14. All output logged to `/var/log/k8s-master-init.log`

## Worker Bootstrap Flow (`userDataWorker.sh.tpl`)

Steps 1–9 identical to master (swap, modules, sysctl, containerd, K8s packages, IMDSv2 IP).  
**Does NOT run `kubeadm join`** — join is performed manually after apply.

---

## IMDSv2 — Mandatory Pattern

Always use the two-step token method. IMDSv1 (direct curl without token) is disabled on hardened instances.

```bash
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $${IMDS_TOKEN}" \
  http://169.254.169.254/latest/meta-data/local-ipv4)
```

Note the `$${}` escaping — `$${IMDS_TOKEN}` renders as `${IMDS_TOKEN}` in the final script.

---

## containerd Configuration

```bash
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup.*/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl enable --now containerd
```

`SystemdCgroup = true` is **required**. Without it, kubelet and containerd use different cgroup drivers and the node won't become Ready.

---

## Cilium Install Pattern

```bash
# Get latest CLI version
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
[ "$(uname -m)" = "aarch64" ] && CLI_ARCH=arm64

# Download, verify, and install
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/$${CILIUM_CLI_VERSION}/cilium-linux-$${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "cilium-linux-$${CLI_ARCH}.tar.gz.sha256sum"
tar xzvfC "cilium-linux-$${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-$${CLI_ARCH}.tar.gz"{,.sha256sum}

# Wait for API server
until kubectl get nodes &>/dev/null; do sleep 5; done

# Install with EC2 flags
cilium install \
  --helm-set kubeProxyReplacement=false \
  --helm-set k8sServiceHost="$${PRIVATE_IP}" \
  --helm-set k8sServicePort=6443
```

`k8sServiceHost` must be the **private IP** — not the public IP.

---

## Join Command Lifecycle

Master saves join command at end of bootstrap:
```bash
JOIN_CMD=$(kubeadm token create --print-join-command)
echo "#!/bin/bash" > /root/kubeadm-join.sh
echo "$${JOIN_CMD}" >> /root/kubeadm-join.sh
chmod 600 /root/kubeadm-join.sh
```

Worker join procedure (manual):
```bash
# 1. SSH into master
ssh -i ~/.ssh/<key>.pem ubuntu@<master_public_ip>

# 2. Read the join command
sudo cat /root/kubeadm-join.sh

# 3. Run on each worker as root
sudo <join_command>

# 4. Verify from master
kubectl get nodes
```

---

## What NOT to Do

| Forbidden | Reason |
|-----------|--------|
| `netplan` / `enp0s8` config | VirtualBox-only, doesn't exist on EC2 |
| IMDSv1 (`curl 169.254.169.254/...` without token) | Disabled on secure instances |
| `${VAR:+expr}` in `.tpl` files | Breaks Terraform template parser — use `if/else` |
| Auto-join in worker userdata | Join token is time-limited; risk of race condition |
| `vagrant` user in scripts | EC2 Ubuntu AMIs use `ubuntu` user |
| `sudo reboot` at end of userdata | cloud-init already handles first-boot; reboot loses logs |

---

## Changing K8s Version

1. Update `k8s_version` in `terraform.tfvars` (format: `v1.XX`)
2. `terraform plan` to confirm `user_data` hash changes for master and workers
3. `terraform apply` recreates instances (new userdata)
4. No manual apt pin changes needed — version is injected via `${k8s_version}` template variable

---

## Debugging Provisioning

```bash
# Check cloud-init / userdata status
cloud-init status --long

# Stream provisioning logs
tail -f /var/log/k8s-master-init.log
tail -f /var/log/k8s-worker-init.log

# Check kubelet
systemctl status kubelet
journalctl -u kubelet -n 50

# Check containerd
systemctl status containerd
```
