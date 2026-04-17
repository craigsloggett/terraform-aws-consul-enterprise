data "aws_iam_policy_document" "consul_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consul" {
  name_prefix        = "${var.project_name}-consul-"
  assume_role_policy = data.aws_iam_policy_document.consul_assume_role.json

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul" })
}

resource "aws_iam_instance_profile" "consul" {
  name_prefix = "${var.project_name}-consul-"
  role        = aws_iam_role.consul.name

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul" })
}

# Secrets Manager (license, gossip key)

data "aws_iam_policy_document" "consul_secrets_manager" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.consul_license.arn,
      aws_secretsmanager_secret.consul_gossip_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "consul_secrets_manager" {
  name_prefix = "${var.project_name}-secrets-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_secrets_manager.json
}

# SSM Parameter Store (Vault PKI managed TLS CA bundle)

data "aws_iam_policy_document" "consul_vault_ca_bundle" {
  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.vault_tls_ca_bundle_ssm_parameter_name}",
    ]
  }
}

resource "aws_iam_role_policy" "consul_vault_ca_bundle" {
  name_prefix = "${var.project_name}-vault-ca-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_vault_ca_bundle.json
}

# Secrets Manager (Nomad ACL token — read/write during initialization)

data "aws_iam_policy_document" "consul_nomad_token" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
    ]
    resources = [aws_secretsmanager_secret.consul_nomad_token.arn]
  }
}

resource "aws_iam_role_policy" "consul_nomad_token" {
  name_prefix = "${var.project_name}-nomad-token-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_nomad_token.json
}

# S3 (snapshots)

data "aws_iam_policy_document" "consul_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]
    resources = [
      aws_s3_bucket.consul_snapshots.arn,
      "${aws_s3_bucket.consul_snapshots.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "consul_s3" {
  name_prefix = "${var.project_name}-s3-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_s3.json
}

# EC2 (auto-join)

data "aws_iam_policy_document" "consul_ec2_describe" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "consul_ec2_describe" {
  name_prefix = "${var.project_name}-ec2-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_ec2_describe.json
}
