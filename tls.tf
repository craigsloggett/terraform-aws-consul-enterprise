# Gossip Encryption Key

resource "random_id" "gossip_key" {
  byte_length = 32
}

# Secrets Manager

resource "aws_secretsmanager_secret" "consul_enterprise_license" {
  name_prefix = "${var.project_name}-consul-license-"
  description = "Consul Enterprise License"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-license" })
}

resource "aws_secretsmanager_secret_version" "consul_enterprise_license" {
  secret_id     = aws_secretsmanager_secret.consul_enterprise_license.id
  secret_string = var.consul_enterprise_license
}

resource "aws_secretsmanager_secret" "consul_gossip_key" {
  name_prefix = "${var.project_name}-consul-gossip-key-"
  description = "Consul Gossip Encryption Key"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-gossip-key" })
}

resource "aws_secretsmanager_secret_version" "consul_gossip_key" {
  secret_id     = aws_secretsmanager_secret.consul_gossip_key.id
  secret_string = random_id.gossip_key.b64_std
}

# Self-Signed CA

resource "tls_private_key" "consul_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "consul_ca" {
  private_key_pem = tls_private_key.consul_ca.private_key_pem

  subject {
    common_name = "${title(var.project_name)} Consul CA"
  }

  validity_period_hours = 87600 # 10 years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Server Certificate

resource "tls_private_key" "consul_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "consul_server" {
  private_key_pem = tls_private_key.consul_server.private_key_pem

  subject {
    common_name = local.consul_fqdn
  }

  dns_names = [
    "server.${var.consul_datacenter}.consul",
    "*.${var.route53_zone.name}",
    local.consul_fqdn,
    "localhost",
  ]

  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "consul_server" {
  cert_request_pem   = tls_cert_request.consul_server.cert_request_pem
  ca_private_key_pem = tls_private_key.consul_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.consul_ca.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# TLS Secrets

resource "aws_secretsmanager_secret" "consul_ca_cert" {
  name_prefix = "${var.project_name}-consul-ca-cert-"
  description = "Consul Self-signed CA Certificate"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-ca-cert" })
}

resource "aws_secretsmanager_secret_version" "consul_ca_cert" {
  secret_id     = aws_secretsmanager_secret.consul_ca_cert.id
  secret_string = tls_self_signed_cert.consul_ca.cert_pem
}

resource "aws_secretsmanager_secret" "consul_server_cert" {
  name_prefix = "${var.project_name}-consul-server-cert-"
  description = "Consul Server TLS Certificate"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-server-cert" })
}

resource "aws_secretsmanager_secret_version" "consul_server_cert" {
  secret_id     = aws_secretsmanager_secret.consul_server_cert.id
  secret_string = tls_locally_signed_cert.consul_server.cert_pem
}

resource "aws_secretsmanager_secret" "consul_server_key" {
  name_prefix = "${var.project_name}-consul-server-key-"
  description = "Consul Server TLS Private Key"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-server-key" })
}

resource "aws_secretsmanager_secret_version" "consul_server_key" {
  secret_id     = aws_secretsmanager_secret.consul_server_key.id
  secret_string = tls_private_key.consul_server.private_key_pem
}

# Bootstrap Tokens (Populated During Cluster Initialization)

resource "aws_secretsmanager_secret" "consul_bootstrap_token" {
  name_prefix = "${var.project_name}-consul-bootstrap-token-"
  description = "Consul ACL Bootstrap Token"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-bootstrap-token" })
}
