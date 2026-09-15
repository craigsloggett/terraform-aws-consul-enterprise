# Vault Prerequisites
#
# Everything the module expects to exist in Vault ahead of time: a PKI mount
# and role for the Consul server certificates, an AWS auth role bound to the
# module's IAM role, the gossip encryption key in KV v2, and a policy tying
# them together. The module itself never configures Vault.

## PKI

resource "vault_mount" "pki_consul" {
  path        = "pki_consul"
  type        = "pki"
  description = "PKI for the Consul Enterprise server certificates"

  # 3 years
  max_lease_ttl_seconds = 94608000
}

resource "vault_pki_secret_backend_root_cert" "consul" {
  backend = vault_mount.pki_consul.path
  type    = "internal"

  common_name = "Consul PKI Root CA"
  key_type    = "ec"
  key_bits    = 384

  # 3 years
  ttl = "94608000"
}

resource "vault_pki_secret_backend_role" "consul_server" {
  backend = vault_mount.pki_consul.path
  name    = "consul-server"

  # The server certificate carries the public FQDN, the Consul-internal
  # server.<datacenter>.consul name (required by verify_server_hostname),
  # localhost, and 127.0.0.1.
  allowed_domains    = [var.consul_fqdn, "server.dc1.consul"]
  allow_bare_domains = true
  allow_subdomains   = false
  allow_localhost    = true
  allow_ip_sans      = true

  key_type = "ec"
  key_bits = 384

  # 24 hours
  max_ttl = 86400
}

## AWS Auth

resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "aws"
}

resource "vault_aws_auth_backend_role" "consul_server" {
  backend   = vault_auth_backend.aws.path
  role      = "consul-server"
  auth_type = "iam"

  bound_iam_principal_arns = [module.consul.iam_role_arn]

  # ARN string matching instead of unique ID pinning, so the Vault cluster
  # does not need iam:GetRole on the Consul server role.
  resolve_aws_unique_ids = false

  token_policies = [vault_policy.consul_server.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

resource "vault_policy" "consul_server" {
  name = "consul-server"

  policy = <<-EOT
    path "${vault_mount.pki_consul.path}/issue/consul-server" {
      capabilities = ["create", "update"]
    }

    path "${vault_mount.kv.path}/data/consul/gossip" {
      capabilities = ["read"]
    }
  EOT
}

## Gossip Encryption Key

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  description = "KV v2 secrets for the Consul Enterprise servers"

  options = {
    version = "2"
  }
}

resource "random_bytes" "gossip_key" {
  length = 32
}

resource "vault_kv_secret_v2" "consul_gossip" {
  mount = vault_mount.kv.path
  name  = "consul/gossip"

  data_json = jsonencode({
    key = random_bytes.gossip_key.base64
  })
}
