variable "consul_enterprise_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}

variable "consul_fqdn" {
  type        = string
  description = "Fully qualified domain name in presentation form for the Consul Enterprise cluster."
}

variable "vault_address" {
  type        = string
  description = "HTTPS URL of the existing Vault cluster that manages PKI for the Consul servers."
}

variable "vault_ca_chain_pem" {
  type        = string
  description = "PEM-encoded CA chain the Consul servers use to verify the Vault cluster's TLS certificate."
}
