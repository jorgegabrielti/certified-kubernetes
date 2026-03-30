# ─── Project identity ─────────────────────────────────────────────────────────

variable "project" {
  description = "Project name used as a prefix for all resource names."
  type        = string
  default     = "cka-studies"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Additional tags to merge with the common tag set."
  type        = map(string)
  default     = {}
}

# ─── AWS provider ─────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region where all resources will be created."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region (e.g. us-east-1, sa-east-1)."
  }
}

variable "aws_profile" {
  description = "AWS CLI named profile to use for authentication."
  type        = string
  default     = "terraform"
}

# ─── Network ──────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "pod_network_cidr" {
  description = "CIDR block for Kubernetes pod networking (passed to kubeadm --pod-network-cidr)."
  type        = string
  default     = "10.244.0.0/16"
}

# ─── EC2 ──────────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type for all cluster nodes."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = contains(["t3.medium", "t3.large", "t3.xlarge"], var.instance_type)
    error_message = "instance_type must be one of: t3.medium, t3.large, t3.xlarge."
  }
}

variable "instance_ami" {
  description = "AMI ID for cluster nodes. Defaults to Ubuntu 22.04 LTS (us-east-1)."
  type        = string
  default     = "ami-0e1bed4f06a3b463d"
}

variable "key_name" {
  description = "Name for the EC2 key pair. Terraform will create it and save the private key to ~/.ssh/<key_name>.pem."
  type        = string
  default     = "cka-keypair"
}

variable "worker_count" {
  description = "Number of worker nodes to provision."
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 5
    error_message = "worker_count must be between 1 and 5."
  }
}

# ─── Kubernetes ───────────────────────────────────────────────────────────────

variable "k8s_version" {
  description = "Kubernetes minor version track to install (e.g. v1.31)."
  type        = string
  default     = "v1.31"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+$", var.k8s_version))
    error_message = "k8s_version must match the pattern vMAJOR.MINOR (e.g. v1.31)."
  }
}