locals {
  iam_project_name = replace(title(replace(var.project_name, "-", " ")), " ", "")
}

data "aws_iam_policy_document" "consul_server_instance_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consul_server_instance" {
  name               = "ConsulServer${local.iam_project_name}InstanceRole"
  assume_role_policy = data.aws_iam_policy_document.consul_server_instance_assume_role.json

  tags = merge(var.common_tags, { Name = "ConsulServer${local.iam_project_name}InstanceRole" })
}

resource "aws_iam_instance_profile" "consul_server_instance" {
  name = "ConsulServer${local.iam_project_name}InstanceProfile"
  role = aws_iam_role.consul_server_instance.name

  tags = merge(var.common_tags, { Name = "ConsulServer${local.iam_project_name}InstanceProfile" })
}

# Secrets Manager (license, gossip key, TLS materials)

data "aws_iam_policy_document" "consul_server_secrets_manager_read" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.consul_enterprise_license.arn,
      aws_secretsmanager_secret.consul_gossip_key.arn,
      aws_secretsmanager_secret.consul_ca.arn,
      aws_secretsmanager_secret.consul_server_cert.arn,
      aws_secretsmanager_secret.consul_server_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "consul_server_secrets_manager_read" {
  name   = "ConsulServer${local.iam_project_name}SecretsManagerReadPolicy"
  role   = aws_iam_role.consul_server_instance.id
  policy = data.aws_iam_policy_document.consul_server_secrets_manager_read.json
}

# SSM Parameter Store (cluster coordination)

data "aws_iam_policy_document" "consul_server_ssm_read_write" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]
    resources = [aws_ssm_parameter.consul_cluster_state.arn]
  }
}

resource "aws_iam_role_policy" "consul_server_ssm_read_write" {
  name   = "ConsulServer${local.iam_project_name}SSMReadWritePolicy"
  role   = aws_iam_role.consul_server_instance.id
  policy = data.aws_iam_policy_document.consul_server_ssm_read_write.json
}

# Secrets Manager (bootstrap token — read/write during initialization)

data "aws_iam_policy_document" "consul_server_secrets_manager_read_write" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
    ]
    resources = [aws_secretsmanager_secret.consul_bootstrap_token.arn]
  }
}

resource "aws_iam_role_policy" "consul_server_secrets_manager_read_write" {
  name   = "ConsulServer${local.iam_project_name}SecretsManagerReadWritePolicy"
  role   = aws_iam_role.consul_server_instance.id
  policy = data.aws_iam_policy_document.consul_server_secrets_manager_read_write.json
}

# S3 (snapshots)

data "aws_iam_policy_document" "consul_server_s3_read_write" {
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

resource "aws_iam_role_policy" "consul_server_s3_read_write" {
  name   = "ConsulServer${local.iam_project_name}S3ReadWritePolicy"
  role   = aws_iam_role.consul_server_instance.id
  policy = data.aws_iam_policy_document.consul_server_s3_read_write.json
}

# EC2 (auto-join)

data "aws_iam_policy_document" "consul_server_ec2_read" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "consul_server_ec2_read" {
  name   = "ConsulServer${local.iam_project_name}EC2ReadPolicy"
  role   = aws_iam_role.consul_server_instance.id
  policy = data.aws_iam_policy_document.consul_server_ec2_read.json
}
