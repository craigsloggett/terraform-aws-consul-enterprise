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

# Bootstrap Tokens (Populated During Cluster Initialization)

resource "aws_secretsmanager_secret" "consul_bootstrap_token" {
  name_prefix = "${var.project_name}-consul-bootstrap-token-"
  description = "Consul Bootstrap ACL Token"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-bootstrap-token" })
}
