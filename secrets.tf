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
  secret_string = var.consul_gossip_key
}

# TLS Secrets

resource "aws_secretsmanager_secret" "consul_ca" {
  name_prefix = "${var.project_name}-consul-ca-"
  description = "Consul Self-signed CA"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-ca" })
}

resource "aws_secretsmanager_secret_version" "consul_ca" {
  secret_id     = aws_secretsmanager_secret.consul_ca.id
  secret_string = var.consul_ca_cert_pem
}

moved {
  from = aws_secretsmanager_secret.consul_ca_cert
  to   = aws_secretsmanager_secret.consul_ca
}

moved {
  from = aws_secretsmanager_secret_version.consul_ca_cert
  to   = aws_secretsmanager_secret_version.consul_ca
}

resource "aws_secretsmanager_secret" "consul_server_cert" {
  name_prefix = "${var.project_name}-consul-server-cert-"
  description = "Consul Server TLS Certificate"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-server-cert" })
}

resource "aws_secretsmanager_secret_version" "consul_server_cert" {
  secret_id     = aws_secretsmanager_secret.consul_server_cert.id
  secret_string = var.consul_server_cert_pem
}

resource "aws_secretsmanager_secret" "consul_server_key" {
  name_prefix = "${var.project_name}-consul-server-key-"
  description = "Consul Server TLS Private Key"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-server-key" })
}

resource "aws_secretsmanager_secret_version" "consul_server_key" {
  secret_id     = aws_secretsmanager_secret.consul_server_key.id
  secret_string = var.consul_server_key_pem
}

# Bootstrap Tokens (Populated During Cluster Initialization)

resource "aws_secretsmanager_secret" "consul_bootstrap_token" {
  name_prefix = "${var.project_name}-consul-bootstrap-token-"
  description = "Consul Bootstrap ACL Token"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-bootstrap-token" })
}
