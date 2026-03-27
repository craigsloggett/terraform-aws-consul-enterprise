output "vpc_id" {
  description = "VPC ID (created or existing)."
  value       = local.vpc.id
}

output "consul_url" {
  description = "URL of the Consul cluster."
  value       = "https://${local.consul_fqdn}:8501"
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "consul_private_ips" {
  description = "Private IPs of the Consul nodes."
  value       = aws_instance.consul[*].private_ip
}

output "consul_snapshot_bucket" {
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
  description = "CA certificate for trusting the Consul TLS chain."
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}
