variable "instance_count" {
  description = "Number of instances to create."
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "instance_ami" {
  description = "AMI ID for the EC2 instances."
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair."
  type        = string
}

variable "sg_id" {
  description = "Security group ID to attach to the instances."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where instances will be launched."
  type        = string
}

variable "user_data" {
  description = "Rendered user data script (plain text; will be base64-encoded). Null = sem bootstrap."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix applied to the Name tag."
  type        = string
}

variable "role" {
  description = "Node role label used in the Name tag (e.g. master, worker)."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to each instance."
  type        = map(string)
  default     = {}
}