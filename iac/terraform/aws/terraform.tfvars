# ─── Project ──────────────────────────────────────────────────────────────────
project     = "cka-studies"
environment = "dev"

# ─── AWS ──────────────────────────────────────────────────────────────────────
aws_region  = "us-east-1"
aws_profile = "terraform"

# ─── Network ──────────────────────────────────────────────────────────────────
vpc_cidr         = "10.0.0.0/16"
subnet_cidr      = "10.0.1.0/24"
pod_network_cidr = "10.244.0.0/16"

# ─── EC2 ──────────────────────────────────────────────────────────────────────
instance_type = "t3.medium"
instance_ami  = "ami-0e1bed4f06a3b463d" # Ubuntu 22.04 LTS — us-east-1
key_name      = "cka-keypair"
worker_count  = 0

# ─── Kubernetes ───────────────────────────────────────────────────────────────
k8s_version = "v1.31"

