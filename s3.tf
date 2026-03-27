resource "aws_s3_bucket" "consul_snapshots" {
  bucket           = "${var.project_name}-consul-snapshots-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}-an"
  bucket_namespace = "account-regional"
  force_destroy    = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-snapshots" })
}

resource "aws_s3_bucket_versioning" "consul_snapshots" {
  bucket = aws_s3_bucket.consul_snapshots.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "consul_snapshots" {
  bucket = aws_s3_bucket.consul_snapshots.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "consul_snapshots" {
  bucket = aws_s3_bucket.consul_snapshots.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "consul_snapshots" {
  bucket = aws_s3_bucket.consul_snapshots.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "consul_snapshots" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.consul_snapshots.arn,
      "${aws_s3_bucket.consul_snapshots.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "consul_snapshots" {
  bucket = aws_s3_bucket.consul_snapshots.id
  policy = data.aws_iam_policy_document.consul_snapshots.json
}
