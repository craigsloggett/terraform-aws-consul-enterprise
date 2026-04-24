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

# Bootstrap Tokens (Populated During Cluster Initialization)

resource "aws_secretsmanager_secret" "consul_bootstrap_token" {
  name_prefix = "${var.project_name}-consul-bootstrap-token-"
  description = "Consul ACL bootstrap token (populated during cluster initialization)"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-bootstrap-token" })
}

resource "aws_secretsmanager_secret" "consul_agent_token" {
  name_prefix = "${var.project_name}-consul-agent-token-"
  description = "Consul server agent ACL token (populated during cluster initialization)"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-agent-token" })
}
