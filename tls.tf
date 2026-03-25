# CA

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.project_name} CA"
    organization = var.project_name
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Server

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = local.consul_fqdn
    organization = var.project_name
  }

  dns_names = [
    local.consul_fqdn,
    "server.${var.consul_datacenter}.consul",
    "*.${var.route53_zone.name}",
    "localhost",
  ]

  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# Gossip Encryption Key

resource "random_id" "gossip_key" {
  byte_length = 32
}

# Secrets Manager

resource "aws_secretsmanager_secret" "consul_ca_cert" {
  name_prefix = "${var.project_name}-consul-ca-cert-"
  description = "Consul CA certificate"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-ca-cert" })
}

resource "aws_secretsmanager_secret_version" "consul_ca_cert" {
  secret_id     = aws_secretsmanager_secret.consul_ca_cert.id
  secret_string = tls_self_signed_cert.ca.cert_pem
}

resource "aws_secretsmanager_secret" "consul_server_cert" {
  name_prefix = "${var.project_name}-consul-server-cert-"
  description = "Consul server certificate"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-server-cert" })
}

resource "aws_secretsmanager_secret_version" "consul_server_cert" {
  secret_id     = aws_secretsmanager_secret.consul_server_cert.id
  secret_string = tls_locally_signed_cert.server.cert_pem
}

resource "aws_secretsmanager_secret" "consul_server_key" {
  name_prefix = "${var.project_name}-consul-server-key-"
  description = "Consul server private key"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-server-key" })
}

resource "aws_secretsmanager_secret_version" "consul_server_key" {
  secret_id     = aws_secretsmanager_secret.consul_server_key.id
  secret_string = tls_private_key.server.private_key_pem
}

resource "aws_secretsmanager_secret" "consul_license" {
  name_prefix = "${var.project_name}-consul-license-"
  description = "Consul Enterprise license"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-license" })
}

resource "aws_secretsmanager_secret_version" "consul_license" {
  secret_id     = aws_secretsmanager_secret.consul_license.id
  secret_string = var.consul_license
}

resource "aws_secretsmanager_secret" "consul_gossip_key" {
  name_prefix = "${var.project_name}-consul-gossip-key-"
  description = "Consul gossip encryption key"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-gossip-key" })
}

resource "aws_secretsmanager_secret_version" "consul_gossip_key" {
  secret_id     = aws_secretsmanager_secret.consul_gossip_key.id
  secret_string = random_id.gossip_key.b64_std
}
