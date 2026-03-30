# ─── SSH Key Pair ────────────────────────────────────────────────────────────
resource "tls_private_key" "k8s" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s" {
  key_name   = var.key_name
  public_key = tls_private_key.k8s.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.k8s.private_key_pem
  filename        = pathexpand("~/.ssh/${var.key_name}.pem")
  file_permission = "0600"
}

# ─── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name_prefix = local.name_prefix
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
}

# ─── Security Groups ──────────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
}

# ─── Master node ──────────────────────────────────────────────────────────────
module "ec2_master" {
  source = "./modules/ec2_instances"

  instance_count = 1
  instance_type  = var.instance_type
  instance_ami   = var.instance_ami
  key_name       = aws_key_pair.k8s.key_name
  sg_id          = module.security_groups.sg_id
  subnet_id      = module.vpc.subnet_id
  name_prefix    = local.name_prefix
  role           = "master"
  tags           = local.common_tags
}

# ─── Worker nodes ─────────────────────────────────────────────────────────────
module "ec2_workers" {
  source = "./modules/ec2_instances"

  instance_count = var.worker_count
  instance_type  = var.instance_type
  instance_ami   = var.instance_ami
  key_name       = aws_key_pair.k8s.key_name
  sg_id          = module.security_groups.sg_id
  subnet_id      = module.vpc.subnet_id
  name_prefix    = local.name_prefix
  role           = "worker"
  tags           = local.common_tags
}