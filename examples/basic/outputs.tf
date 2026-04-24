output "consul_url" {
  description = "URL of the Consul cluster."
  value       = module.consul.consul_url
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = module.consul.bastion_public_ip
}

output "consul_tls_ca_bundle_ssm_parameter_name" {
  description = "SSM parameter name for the Consul PKI TLS CA bundle."
  value       = module.consul.consul_tls_ca_bundle_ssm_parameter_name
}
