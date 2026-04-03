output "consul_url" {
  description = "URL of the Consul cluster."
  value       = module.consul.consul_url
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = module.consul.bastion_public_ip
}

output "consul_private_ips" {
  description = "Private IPs of the Consul nodes."
  value       = module.consul.consul_private_ips
}

output "consul_snapshot_bucket" {
  description = "S3 bucket for Consul snapshots."
  value       = module.consul.consul_snapshot_bucket
}

output "ec2_ami_name" {
  description = "Name of the AMI used for EC2 instances."
  value       = module.consul.ec2_ami_name
}

output "consul_target_group_arn" {
  description = "ARN of the Consul NLB target group."
  value       = module.consul.consul_target_group_arn
}

output "consul_ca_cert" {
  description = "CA certificate for trusting the Consul TLS chain."
  value       = module.consul.consul_ca_cert
  sensitive   = true
}

output "consul_token_secret_arn" {
  description = "ARN of the Secrets Manager secret for the Consul Nomad token."
  value       = module.consul.nomad_token_secret.arn
}

output "nomad_server_service_name" {
  description = "Consul service name Nomad servers will register as."
  value       = module.consul.nomad_server_service_name
}

output "nomad_client_service_name" {
  description = "Consul service name Nomad clients will register as."
  value       = module.consul.nomad_client_service_name
}
