# Consul Intermediate PKI Mount

resource "vault_mount" "pki_consul" {
  path                      = var.vault_pki_mount
  type                      = "pki"
  description               = "Consul Intermediate PKI"
  max_lease_ttl_seconds     = 94608000
  default_lease_ttl_seconds = 2764800
}

# Policy Scoped to Consul PKI Operations

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
