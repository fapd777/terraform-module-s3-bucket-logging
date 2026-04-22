data "aws_iam_policy_document" "bucket_policy" {

  statement {
    actions = [
      "s3:PutObject"
    ]
    principals {
      identifiers = [
        data.aws_elb_service_account.elb_account.arn
      ]
      type = "AWS"
    }
    resources = [
      "${aws_s3_bucket.bucket.arn}/elb/*"
    ]
    sid = "EnableELBLogging"
  }

  statement {
    sid = "AWSLogDeliveryWrite"
    actions = [
      "s3:PutObject"
    ]
    principals {
      identifiers = [
        "delivery.logs.amazonaws.com"
      ]
      type = "Service"
    }
    resources = [
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }
  }

  statement {
    actions = [
      "s3:GetBucketAcl"
    ]
    principals {
      identifiers = [
        "delivery.logs.amazonaws.com"
      ]
      type = "Service"
    }
    resources = [
      aws_s3_bucket.bucket.arn
    ]
    sid = "AWSLogDeliveryAclCheck"
  }

  statement {
    actions = [
      "s3:GetBucketAcl"
    ]
    principals {
      identifiers = [
        "config.amazonaws.com"
      ]
      type = "Service"
    }
    resources = [
      aws_s3_bucket.bucket.arn
    ]
    sid = "EnableConfigGetACL"
  }

  statement {
    actions = [
      "s3:PutObject"
    ]
    principals {
      identifiers = [
        "config.amazonaws.com"
      ]
      type = "Service"
    }
    resources = [
      "${aws_s3_bucket.bucket.arn}/aws-config/*",
      "${aws_s3_bucket.bucket.arn}/config/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }
    sid = "EnableConfigLogging"
  }

  statement {
    actions = [
      "s3:*"
    ]
    condition {
      test = "Bool"
      values = [
        "false"
      ]
      variable = "aws:SecureTransport"
    }
    effect = "Deny"
    principals {
      identifiers = [
        "*"
      ]
      type = "AWS"
    }
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    sid = "DenyUnsecuredTransport"
  }

  statement {
    actions = [
      "s3:PutObject"
    ]
    condition {
      test = "StringEquals"
      values = [
        data.aws_caller_identity.current.account_id
      ]
      variable = "aws:SourceAccount"
    }
    effect = "Allow"
    principals {
      identifiers = [
        "logging.s3.amazonaws.com"
      ]
      type = "Service"
    }
    resources = [
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    sid = "S3ServerAccessLogsPolicy"
  }
}

#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.name_prefix}-logging${var.name_suffix}"

  lifecycle {
    prevent_destroy = true
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "resource" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = var.versioning_enabled == true ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "Logs"
    status = "Enabled"

    filter {
      prefix = "/"
    }

    transition {
      days          = var.transition_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.transition_glacier
      storage_class = "GLACIER"
    }

    expiration {
      days = var.transition_expiration
    }
  }
  dynamic "rule" {
    for_each = var.enable_object_expiration == true ? [1] : []
    content {
      id     = "Expire-objects"
      status = "Enabled"

      filter {
        prefix = "/"
      }

      expiration {
        days = var.days_to_object_expiration
      }
    }
  }
}

#tfsec:ignore:aws-s3-encryption-customer-key
#trivy:ignore:AVD-AWS-0089
#trivy:ignore:AVD-AWS-0132
#trivy:ignore:AVD-AWS-0088 - ignored because the bucket already allows for encryption with a count var
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  count = var.aws_s3_bucket_server_side_encryption_type != "AWS_DEFAULT" ? 1 : 0

  bucket = aws_s3_bucket.bucket.bucket
  dynamic "rule" {
    for_each = var.aws_s3_bucket_server_side_encryption_type == "SSE_S3" ? [1] : []
    content {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  count = var.versioning_enabled == true && var.enable_centralized_logging == true ? 1 : 0 # If statement if to enable replication

  role   = var.iam_role_s3_replication_arn
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "${var.name_prefix}-replication${var.name_suffix}"
    status = "Enabled"
    destination {
      bucket        = "arn:aws:s3:::${var.s3_destination_bucket_name}"
      storage_class = var.replication_dest_storage_class
      account       = var.logging_account_id
      access_control_translation {
        owner = "Destination"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy_attachment" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
