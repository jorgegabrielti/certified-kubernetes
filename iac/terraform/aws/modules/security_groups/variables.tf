variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the security group will be created."
  type        = string
}
