locals {
  log_forwarding = var.cloudwatch_logs == null ? {} : { enabled = var.cloudwatch_logs }
}

resource "aws_s3_bucket" "logs_backup" {
  for_each = local.log_forwarding

  bucket_prefix = "${each.value.name}-"
  # Keep failed deliveries recoverable; disabling forwarding must not erase them.
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "logs_backup" {
  for_each = local.log_forwarding

  bucket                  = aws_s3_bucket.logs_backup[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_backup" {
  for_each = local.log_forwarding

  bucket = aws_s3_bucket.logs_backup[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_backup" {
  for_each = local.log_forwarding

  bucket = aws_s3_bucket.logs_backup[each.key].id
  rule {
    id     = "expire-failed-deliveries"
    status = "Enabled"
    filter {}
    expiration {
      days = each.value.backup_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "logs_backup" {
  for_each = local.log_forwarding

  bucket = aws_s3_bucket.logs_backup[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.logs_backup[each.key].arn, "${aws_s3_bucket.logs_backup[each.key].arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_cloudwatch_log_group" "firehose" {
  for_each = local.log_forwarding

  name              = "/aws/kinesisfirehose/${each.value.name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "firehose" {
  for_each = local.log_forwarding

  name           = "HttpEndpointDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose[each.key].name
}

resource "aws_iam_role" "firehose" {
  for_each = local.log_forwarding

  name = "${each.value.name}-${data.aws_region.current.name}-delivery"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "sts:ExternalId" = var.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "firehose" {
  for_each = local.log_forwarding

  role = aws_iam_role.firehose[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = [aws_s3_bucket.logs_backup[each.key].arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.logs_backup[each.key].arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = [aws_cloudwatch_log_stream.firehose[each.key].arn]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [each.value.secret_arn]
      }
      ], each.value.secret_kms_key_arn == null ? [] : [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [each.value.secret_kms_key_arn]
        Condition = {
          StringEquals = {
            "kms:ViaService"                  = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
            "kms:EncryptionContext:SecretARN" = each.value.secret_arn
          }
        }
    }])
  })
}

resource "aws_kinesis_firehose_delivery_stream" "logs" {
  for_each = local.log_forwarding

  name        = each.value.name
  destination = "http_endpoint"

  server_side_encryption {
    enabled  = true
    key_type = "AWS_OWNED_CMK"
  }

  http_endpoint_configuration {
    name               = "Dynatrace"
    url                = each.value.endpoint_url
    role_arn           = aws_iam_role.firehose[each.key].arn
    buffering_size     = 1
    buffering_interval = 60
    retry_duration     = 900
    s3_backup_mode     = "FailedDataOnly"

    # Firehose reads the credential at runtime; Terraform never fetches its value.
    secrets_manager_configuration {
      enabled    = true
      secret_arn = each.value.secret_arn
      role_arn   = aws_iam_role.firehose[each.key].arn
    }

    request_configuration {
      content_encoding = "GZIP"
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose[each.key].name
      log_stream_name = aws_cloudwatch_log_stream.firehose[each.key].name
    }

    # Preserve the CloudWatch envelope for Dynatrace's Firehose endpoint.
    # No decompression, message extraction or Lambda transformation is needed.
    s3_configuration {
      role_arn           = aws_iam_role.firehose[each.key].arn
      bucket_arn         = aws_s3_bucket.logs_backup[each.key].arn
      buffering_size     = 5
      buffering_interval = 300
      compression_format = "GZIP"
      prefix             = "failed/"
    }
  }

  lifecycle {
    precondition {
      condition = (
        split(":", each.value.secret_arn)[3] == data.aws_region.current.name &&
        split(":", each.value.secret_arn)[4] == var.account_id
      )
      error_message = "The Firehose ingestion secret must be in the forwarding account and region."
    }
  }

  depends_on = [
    aws_iam_role_policy.firehose,
    aws_s3_bucket_public_access_block.logs_backup,
    aws_s3_bucket_server_side_encryption_configuration.logs_backup,
    aws_s3_bucket_policy.logs_backup,
  ]
}

resource "aws_iam_role" "cloudwatch_logs" {
  for_each = local.log_forwarding

  name = "${each.value.name}-${data.aws_region.current.name}-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringLike = { "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${var.account_id}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  for_each = local.log_forwarding

  role = aws_iam_role.cloudwatch_logs[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
      Resource = [aws_kinesis_firehose_delivery_stream.logs[each.key].arn]
    }]
  })
}

resource "aws_cloudwatch_log_account_policy" "dynatrace" {
  for_each = local.log_forwarding

  policy_name = each.value.name
  policy_type = "SUBSCRIPTION_FILTER_POLICY"
  scope       = "ALL"
  policy_document = jsonencode({
    DestinationArn = aws_kinesis_firehose_delivery_stream.logs[each.key].arn
    RoleArn        = aws_iam_role.cloudwatch_logs[each.key].arn
    FilterPattern  = ""
  })

  # Account-level subscriptions include existing and future log groups.
  # Exclude only the delivery stream's own diagnostics to prevent recursion.
  selection_criteria = "LogGroupName NOT IN ${jsonencode([aws_cloudwatch_log_group.firehose[each.key].name])}"

  depends_on = [aws_iam_role_policy.cloudwatch_logs]
}
