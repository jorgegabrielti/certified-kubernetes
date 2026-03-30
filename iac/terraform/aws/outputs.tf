output "master_public_ip" {
  description = "Public IP of the master node."
  value       = module.ec2_master.public_ips[0]
}

output "master_private_ip" {
  description = "Private IP of the master node."
  value       = module.ec2_master.private_ips[0]
}

output "worker_public_ips" {
  description = "Public IPs of the worker nodes."
  value       = module.ec2_workers.public_ips
}

output "worker_private_ips" {
  description = "Private IPs of the worker nodes."
  value       = module.ec2_workers.private_ips
}

output "ssh_master" {
  description = "SSH command to access the master node."
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2_master.public_ips[0]}"
}

output "ssh_workers" {
  description = "SSH commands to access each worker node."
  value       = [for ip in module.ec2_workers.public_ips : "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${ip}"]
}

output "private_key_path" {
  description = "Local path where the private key was saved."
  value       = local_sensitive_file.private_key.filename
}

output "join_instruction" {
  description = "Steps to join workers to the cluster after boot (~3-5 min)."
  value       = <<-EOT
    1. SSH into the master:    ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2_master.public_ips[0]}
    2. Get the join command:   sudo cat /root/kubeadm-join.sh
    3. Copy and run that command as root on each worker node.
    4. Verify from master:     kubectl get nodes
  EOT
}
