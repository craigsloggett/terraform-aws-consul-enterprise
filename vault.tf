# Consul Intermediate PKI Mount

resource "vault_mount" "pki_consul" {
  path                      = var.vault_pki_mount
  type                      = "pki"
  description               = "Consul intermediate PKI (chained from pki_root)"
  max_lease_ttl_seconds     = 94608000 # 3 years, matches Vault module pattern
  default_lease_ttl_seconds = 2764800  # 32 days
}

resource "vault_pki_secret_backend_config_urls" "pki_consul" {
  backend = vault_mount.pki_consul.path

  issuing_certificates    = ["${var.vault_url}/v1/${vault_mount.pki_consul.path}/ca"]
  crl_distribution_points = ["${var.vault_url}/v1/${vault_mount.pki_consul.path}/crl"]
  ocsp_servers            = ["${var.vault_url}/v1/${vault_mount.pki_consul.path}/ocsp"]
}

resource "vault_pki_secret_backend_intermediate_cert_request" "pki_consul" {
  backend     = vault_mount.pki_consul.path
  type        = "internal"
  common_name = "${var.project_name} Consul Intermediate CA"
  key_type    = "ec"
  key_bits    = 384
}

resource "vault_pki_secret_backend_root_sign_intermediate" "pki_consul" {
  backend      = "pki_root"
  csr          = vault_pki_secret_backend_intermediate_cert_request.pki_consul.csr
  common_name  = "${var.project_name} Consul Intermediate CA"
  organization = var.vault_pki_organization
  country      = var.vault_pki_country
  ttl          = var.vault_pki_intermediate_ttl
}

resource "vault_pki_secret_backend_intermediate_set_signed" "pki_consul" {
  backend     = vault_mount.pki_consul.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.pki_consul.certificate
}

# PKI Role for Consul Servers

resource "vault_pki_secret_backend_role" "consul_server" {
  backend = vault_mount.pki_consul.path
  name    = var.vault_pki_role

  allowed_domains = [
    var.route53_zone.name,
    "${var.consul_datacenter}.consul",
  ]
  allow_bare_domains = true
  allow_subdomains   = true
  allow_glob_domains = true
  allow_localhost    = true
  allow_ip_sans      = true

  key_type = "ec"
  key_bits = 384

  ext_key_usage = ["ServerAuth", "ClientAuth"]

  max_ttl = 86400 # 24h
}

# Policy Tightly Scoped to Issue Consul Server Certificates

resource "vault_policy" "consul_server" {
  name = "consul-server"

  policy = templatefile("${path.module}/templates/policies/consul-server.hcl.tftpl", {
    pki_path = vault_mount.pki_consul.path
    pki_role = var.vault_pki_role
  })
}

# AWS Auth Role Bound to the Consul Server IAM Role

resource "time_sleep" "wait_vault_iam_propagation" {
  depends_on      = [aws_iam_role_policy.vault_resolve_consul_role]
  create_duration = "30s"
}

resource "vault_aws_auth_backend_role" "consul_server" {
  backend = "aws"
  role    = var.vault_aws_auth_role

  auth_type                = "iam"
  bound_iam_principal_arns = [aws_iam_role.consul.arn]
  token_policies           = [vault_policy.consul_server.name]
  token_ttl                = 14400 # 4h
  token_max_ttl            = 86400 # 24h

  depends_on = [time_sleep.wait_vault_iam_propagation]
}

# Grant the Vault Server IAM Role Permission to Resolve the Consul Server Role
#
# Vault's AWS auth method calls iam:GetRole from the Vault server's own role
# when resolving a bound IAM principal during login. Without this grant,
# login attempts from Consul servers fail with an AccessDenied error.

data "aws_iam_policy_document" "vault_resolve_consul_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:GetRole"]
    resources = [aws_iam_role.consul.arn]
  }
}

resource "aws_iam_role_policy" "vault_resolve_consul_role" {
  name_prefix = "${var.project_name}-resolve-consul-"
  role        = var.vault_iam_role_name
  policy      = data.aws_iam_policy_document.vault_resolve_consul_role.json
}
