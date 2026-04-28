variable "consul_enterprise_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}

variable "vault_ca_cert_pem" {
  type        = string
  description = "PEM CA bundle used by Vault Agent on each Consul node to verify the Vault TLS endpoint."
  sensitive   = true
}
