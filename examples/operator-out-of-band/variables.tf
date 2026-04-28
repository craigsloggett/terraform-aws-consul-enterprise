variable "consul_enterprise_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}

variable "consul_ca_cert_pem" {
  type        = string
  description = "PEM-encoded CA bundle (root and any intermediates) signed out of band by the operator."
  sensitive   = true
}

variable "consul_server_cert_pem" {
  type        = string
  description = "PEM-encoded Consul server certificate signed by the operator's CA."
  sensitive   = true
}

variable "consul_server_key_pem" {
  type        = string
  description = "PEM-encoded private key for the Consul server certificate."
  sensitive   = true
}
