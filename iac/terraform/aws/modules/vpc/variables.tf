variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS region (used to derive the availability zone)."
  type        = string
}

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
