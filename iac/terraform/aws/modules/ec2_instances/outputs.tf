output "public_ips" {
  description = "Public IP addresses of the instances."
  value       = aws_instance.this[*].public_ip
}

output "private_ips" {
  description = "Private IP addresses of the instances."
  value       = aws_instance.this[*].private_ip
}

output "instance_ids" {
  description = "EC2 instance IDs."
  value       = aws_instance.this[*].id
}
