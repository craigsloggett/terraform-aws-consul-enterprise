output "vpc_id" {
  description = "VPC ID (created or existing)."
  value       = local.vpc.id
}

output "consul_url" {
  description = "URL of the Consul cluster."
  value       = "https://${local.consul_fqdn}"
}

output "consul_version" {
  description = "Consul Enterprise version deployed."
  value       = var.consul_version
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "consul_private_ips" {
  description = "Private IPs of the Consul nodes."
  value       = aws_instance.consul[*].private_ip
}

output "consul_snapshots_bucket" {
  description = "S3 bucket for Consul snapshots."
  value       = aws_s3_bucket.consul_snapshots.id
}

output "consul_target_group_arn" {
  description = "ARN of the Consul NLB target group."
  value       = aws_lb_target_group.consul.arn
}

output "ec2_ami_name" {
  description = "Name of the AMI used for EC2 instances."
  value       = var.ec2_ami.name
}

output "consul_ca_cert" {
  description = "CA certificate for trusting the Consul TLS chain (Vault Consul intermediate CA)."
  value       = vault_pki_secret_backend_root_sign_intermediate.pki_consul.certificate
  sensitive   = true
}

output "security_group" {
  description = "Consul cluster security group."
  value       = aws_security_group.consul
}

output "gossip_key_secret" {
  description = "Secrets Manager secret containing the Consul gossip encryption key."
  value       = aws_secretsmanager_secret.consul_gossip_key
}

output "nomad_token_secret" {
  description = "Secrets Manager secret containing the Consul ACL token for Nomad."
  value       = aws_secretsmanager_secret.consul_nomad_token
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the Consul cluster."
  value       = local.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the Consul cluster."
  value       = local.vpc.public_subnet_ids
}

output "consul_auto_join_ec2_tag" {
  description = "EC2 tag key and value used for Consul auto-join."
  value = {
    key   = local.cluster_tag_key
    value = local.cluster_tag_value
  }
}

output "datacenter" {
  description = "Consul datacenter name."
  value       = var.consul_datacenter
}

output "nomad_server_service_name" {
  description = "Consul service name Nomad servers will register as."
  value       = var.nomad_server_service_name
}

output "nomad_client_service_name" {
  description = "Consul service name Nomad clients will register as."
  value       = var.nomad_client_service_name
}

output "nomad_snapshot_service_name" {
  description = "Consul service name the Nomad snapshot agent will register as."
  value       = var.nomad_snapshot_service_name
}
