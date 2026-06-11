output "consul_url" {
  description = "URL of the Consul cluster."
  value       = module.consul.consul_url
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = module.consul.bastion_public_ip
}

output "nlb_dns_name" {
  description = "AWS-assigned DNS name of the Consul NLB."
  value       = module.consul.nlb_dns_name
}

output "nlb_zone_id" {
  description = "Hosted zone ID of the Consul NLB."
  value       = module.consul.nlb_zone_id
}

output "iam_role_arn" {
  description = "ARN of the Consul server IAM role bound to the Vault AWS auth role."
  value       = module.consul.iam_role_arn
}
