resource "aws_secretsmanager_secret" "license" {
  name_prefix = var.consul.secretsmanager_secret.license_name_prefix
  description = "Consul Enterprise License"
}

resource "aws_secretsmanager_secret_version" "license" {
  secret_id     = aws_secretsmanager_secret.license.id
  secret_string = var.consul_enterprise_license
}

resource "aws_secretsmanager_secret" "acl_management_token" {
  name_prefix = var.consul.secretsmanager_secret.acl_management_token_name_prefix
  description = "Consul Enterprise ACL Management Token"
}

resource "aws_secretsmanager_secret" "acl_agent_token" {
  name_prefix = var.consul.secretsmanager_secret.acl_agent_token_name_prefix
  description = "Consul Enterprise ACL Server Agent Token"
}

resource "aws_secretsmanager_secret" "acl_snapshot_agent_token" {
  name_prefix = var.consul.secretsmanager_secret.acl_snapshot_agent_token_name_prefix
  description = "Consul Enterprise ACL Snapshot Agent Token"
}
