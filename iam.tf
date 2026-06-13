data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "EC2InstanceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consul_enterprise" {
  name               = var.iam_role.name
  path               = var.iam_role.path
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "consul_enterprise" {
  name = var.iam_role.instance_profile.name
  path = var.iam_role.instance_profile.path
  role = aws_iam_role.consul_enterprise.name
}

data "aws_iam_policy_document" "secrets_manager_read" {
  statement {
    sid       = "BootstrapMaterialRead"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.license.arn]
  }
}

resource "aws_iam_role_policy" "secrets_manager_read" {
  name   = var.iam_role.inline_policy_names.secrets_manager_read
  role   = aws_iam_role.consul_enterprise.id
  policy = data.aws_iam_policy_document.secrets_manager_read.json
}

data "aws_iam_policy_document" "secrets_manager_read_write" {
  statement {
    sid    = "ClusterInitOutputPersistence"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.acl_management_token.arn,
      aws_secretsmanager_secret.acl_agent_token.arn,
      aws_secretsmanager_secret.acl_snapshot_agent_token.arn,
    ]
  }
}

resource "aws_iam_role_policy" "secrets_manager_read_write" {
  name   = var.iam_role.inline_policy_names.secrets_manager_read_write
  role   = aws_iam_role.consul_enterprise.id
  policy = data.aws_iam_policy_document.secrets_manager_read_write.json
}

data "aws_iam_policy_document" "s3_object_read_write" {
  statement {
    sid    = "RaftSnapshotObjectManagement"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.snapshots.arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_object_read_write" {
  name   = var.iam_role.inline_policy_names.s3_object_read_write
  role   = aws_iam_role.consul_enterprise.id
  policy = data.aws_iam_policy_document.s3_object_read_write.json
}

data "aws_iam_policy_document" "s3_bucket_list" {
  statement {
    sid       = "RaftSnapshotEnumeration"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.snapshots.arn]
  }
}

resource "aws_iam_role_policy" "s3_bucket_list" {
  name   = var.iam_role.inline_policy_names.s3_bucket_list
  role   = aws_iam_role.consul_enterprise.id
  policy = data.aws_iam_policy_document.s3_bucket_list.json
}

data "aws_iam_policy_document" "ec2_describe" {
  statement {
    sid       = "RetryJoinDiscovery"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_describe" {
  name   = var.iam_role.inline_policy_names.ec2_describe
  role   = aws_iam_role.consul_enterprise.id
  policy = data.aws_iam_policy_document.ec2_describe.json
}

data "aws_iam_policy_document" "ssm_read_write" {
  statement {
    sid    = "ClusterCoordinationState"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]

    resources = [
      aws_ssm_parameter.bootstrap_consul_cluster_state.arn,
      aws_ssm_parameter.bootstrap_consul_pki_ca_chain.arn,
      aws_ssm_parameter.bootstrap_instance_id.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ssm_read_write" {
  name   = var.iam_role.inline_policy_names.ssm_read_write
  role   = aws_iam_role.consul_enterprise.id
  policy = data.aws_iam_policy_document.ssm_read_write.json
}
