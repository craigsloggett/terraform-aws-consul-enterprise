# Gossip Encryption Key

resource "random_id" "gossip_key" {
  byte_length = 32
}

# Secrets Manager

resource "aws_secretsmanager_secret" "consul_enterprise_license" {
  name_prefix = "${var.project_name}-consul-license-"
  description = "Consul Enterprise license"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-license" })
}

resource "aws_secretsmanager_secret_version" "consul_enterprise_license" {
  secret_id     = aws_secretsmanager_secret.consul_enterprise_license.id
  secret_string = var.consul_enterprise_license
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

# Placeholder Secrets (Populated After ACL Bootstrap)

resource "aws_secretsmanager_secret" "consul_nomad_token" {
  name_prefix = "${var.project_name}-consul-nomad-token-"
  description = "Consul ACL token for Nomad (populated after ACL bootstrap)"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-nomad-token" })
}
