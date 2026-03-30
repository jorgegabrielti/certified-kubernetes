output "sg_id" {
  description = "ID of the Kubernetes cluster security group."
  value       = aws_security_group.k8s.id
}
