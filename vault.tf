resource "vault_mount" "consul_bootstrap" {
  path        = "kv/consul"
  type        = "kv-v2"
  description = "Infrastructure bootstrap secrets for Consul"
}

resource "vault_policy" "consul_server" {
  name   = "consul-server"
  policy = file("${path.module}/files/consul-server.hcl")
}

resource "vault_aws_auth_backend_role" "consul_server" {
  backend                  = "aws"
  role                     = "consul-server"
  auth_type                = "iam"
  bound_iam_principal_arns = [aws_iam_role.consul.arn]
  resolve_aws_unique_ids   = true
  token_policies           = [vault_policy.consul_server.name]
  token_ttl                = 3600
  token_max_ttl            = 7200
  token_period             = 3600
}

# PKI — Consul Intermediate CA

resource "vault_mount" "pki_consul" {
  path                      = "pki_consul"
  type                      = "pki"
  description               = "Consul intermediate CA"
  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 315360000
}

resource "vault_pki_secret_backend_config_urls" "pki_consul" {
  backend = vault_mount.pki_consul.path

  issuing_certificates    = ["https://${var.vault_fqdn}:8200/v1/${vault_mount.pki_consul.path}/ca"]
  crl_distribution_points = ["https://${var.vault_fqdn}:8200/v1/${vault_mount.pki_consul.path}/crl"]
  ocsp_servers            = ["https://${var.vault_fqdn}:8200/v1/${vault_mount.pki_consul.path}/ocsp"]
}

resource "vault_pki_secret_backend_intermediate_cert_request" "pki_consul" {
  backend     = vault_mount.pki_consul.path
  type        = "internal"
  common_name = "${var.project_name} Consul Intermediate CA"
  key_type    = "ec"
  key_bits    = 384
}

resource "vault_pki_secret_backend_root_sign_intermediate" "pki_consul" {
  backend         = var.vault_pki_root_backend
  csr             = vault_pki_secret_backend_intermediate_cert_request.pki_consul.csr
  common_name     = "${var.project_name} Consul Intermediate CA"
  organization    = var.vault_pki_organization
  country         = var.vault_pki_country
  format          = "pem_bundle"
  max_path_length = 0
  ttl             = 157680000
}

resource "vault_pki_secret_backend_intermediate_set_signed" "pki_consul" {
  backend     = vault_mount.pki_consul.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.pki_consul.certificate
}

resource "vault_pki_secret_backend_role" "consul_server" {
  backend = vault_mount.pki_consul.path
  name    = "consul-server"

  allowed_domains = [
    "server.${var.consul_datacenter}.consul",
    local.consul_fqdn,
  ]
  allow_subdomains = true
  allow_ip_sans    = true
  key_type         = "ec"
  key_bits         = 384
  ttl              = 259200
  max_ttl          = 259200
}

resource "vault_pki_secret_backend_role" "consul_client" {
  backend = vault_mount.pki_consul.path
  name    = "consul-client"

  allowed_domains  = ["client.${var.consul_datacenter}.consul"]
  allow_subdomains = true
  allow_ip_sans    = true
  key_type         = "ec"
  key_bits         = 384
  ttl              = 259200
  max_ttl          = 259200
}

# KV — Bootstrap Secrets

resource "vault_kv_secret_v2" "consul_gossip" {
  mount               = vault_mount.consul_bootstrap.path
  name                = "bootstrap/gossip"
  delete_all_versions = true

  data_json = jsonencode({
    key = random_id.gossip_key.b64_std
  })
}

data "vault_pki_secret_backend_issuer" "pki_consul" {
  backend    = vault_mount.pki_consul.path
  issuer_ref = "default"

  depends_on = [vault_pki_secret_backend_intermediate_set_signed.pki_consul]
}

resource "vault_kv_secret_v2" "consul_ca" {
  mount = vault_mount.consul_bootstrap.path
  name  = "bootstrap/ca"

  data_json = jsonencode({
    ca_cert = data.vault_pki_secret_backend_issuer.pki_consul.certificate
  })
}

resource "vault_kv_secret_v2" "consul_bootstrap_token" {
  mount               = vault_mount.consul_bootstrap.path
  name                = "bootstrap/bootstrap-token"
  delete_all_versions = true

  data_json = jsonencode({
    token = ""
  })
}
