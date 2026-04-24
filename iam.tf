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
      aws_secretsmanager_secret.consul_enterprise_license.arn,
      aws_secretsmanager_secret.consul_gossip_key.arn,
      aws_secretsmanager_secret.consul_ca_cert.arn,
      aws_secretsmanager_secret.consul_server_cert.arn,
      aws_secretsmanager_secret.consul_server_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "consul_secrets_manager" {
  name_prefix = "${var.project_name}-secrets-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_secrets_manager.json
}

# SSM Parameter Store (cluster coordination)

data "aws_iam_policy_document" "consul_cluster_state" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]
    resources = [aws_ssm_parameter.consul_cluster_state.arn]
  }
}

resource "aws_iam_role_policy" "consul_cluster_state" {
  name_prefix = "${var.project_name}-cluster-state-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_cluster_state.json
}

# Secrets Manager (bootstrap token — read/write during initialization)

data "aws_iam_policy_document" "consul_bootstrap_token" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
    ]
    resources = [aws_secretsmanager_secret.consul_bootstrap_token.arn]
  }
}

resource "aws_iam_role_policy" "consul_bootstrap_token" {
  name_prefix = "${var.project_name}-bootstrap-token-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_bootstrap_token.json
}

# Secrets Manager (agent token — read/write during initialization)

data "aws_iam_policy_document" "consul_agent_token" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
    ]
    resources = [aws_secretsmanager_secret.consul_agent_token.arn]
  }
}

resource "aws_iam_role_policy" "consul_agent_token" {
  name_prefix = "${var.project_name}-agent-token-"
  role        = aws_iam_role.consul.id
  policy      = data.aws_iam_policy_document.consul_agent_token.json
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
