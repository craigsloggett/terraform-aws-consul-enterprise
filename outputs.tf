output "consul_url" {
  description = "URL of the Consul Enterprise cluster."
  value       = "https://${var.consul_fqdn}"
}

output "consul_version" {
  description = "Consul Enterprise version deployed."
  value       = var.consul.version
}

output "consul_datacenter" {
  description = "Consul datacenter name."
  value       = var.consul.datacenter
}

output "iam_role_arn" {
  description = "ARN of the Consul server IAM role. Bind this to the external Vault AWS auth role so the Vault Agents can authenticate."
  value       = aws_iam_role.consul_enterprise.arn
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "nlb_dns_name" {
  description = "AWS-assigned DNS name of the Consul NLB. Use this as the CNAME target when DNS is managed outside Route 53."
  value       = aws_lb.consul_enterprise.dns_name
}

output "nlb_zone_id" {
  description = "Hosted zone ID of the Consul NLB. Use this when creating a Route 53 alias record outside this module."
  value       = aws_lb.consul_enterprise.zone_id
}

output "autoscaling_group_name" {
  description = "Name of the Consul Enterprise Auto Scaling Group."
  value       = aws_autoscaling_group.consul_enterprise.name
}

output "ami_name" {
  description = "Name of the AMI used for EC2 instances."
  value       = data.aws_ami.selected.name
}

output "consul_snapshot_aws_s3_bucket_name" {
  description = "Name of the S3 bucket for Consul Enterprise snapshots."
  value       = aws_s3_bucket.snapshots.id
}

output "acl_management_token_secret_arn" {
  description = "Secrets Manager ARN holding the ACL management token created by `consul acl bootstrap`."
  value       = aws_secretsmanager_secret.acl_management_token.arn
}

output "bootstrap_consul_cluster_state_ssm_parameter_name" {
  description = "SSM Parameter for the bootstrap initialization state flag."
  value       = aws_ssm_parameter.bootstrap_consul_cluster_state.name
}

output "bootstrap_instance_id_ssm_parameter_name" {
  description = "SSM Parameter for the elected bootstrap node EC2 instance ID."
  value       = aws_ssm_parameter.bootstrap_instance_id.name
}
