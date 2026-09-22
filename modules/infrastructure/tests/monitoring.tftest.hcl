mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "eu-west-2" }
  }

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/test" }
  }

  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::test-backup-bucket" }
  }

  mock_resource "aws_kinesis_firehose_delivery_stream" {
    defaults = { arn = "arn:aws:firehose:eu-west-2:123456789012:deliverystream/dynatrace-cloudwatch-logs" }
  }
  # Keep the mocked JSON valid for the IAM role's provider-side validation.
  # The assertions below inspect the configured trust statements themselves.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  account_id              = "123456789012"
  dynatrace_connection_id = "test-connection-id"
}

run "monitoring_role" {
  command = apply
  assert {
    condition = (
      data.aws_iam_policy_document.assume_role.statement[0].actions == toset(["sts:AssumeRole"]) &&
      one(data.aws_iam_policy_document.assume_role.statement[0].principals).type == "AWS" &&
      one(data.aws_iam_policy_document.assume_role.statement[0].principals).identifiers == toset(["arn:aws:iam::314146291599:root"]) &&
      one(data.aws_iam_policy_document.assume_role.statement[0].condition).test == "StringEquals" &&
      one(data.aws_iam_policy_document.assume_role.statement[0].condition).variable == "sts:ExternalId" &&
      toset(one(data.aws_iam_policy_document.assume_role.statement[0].condition).values) == toset([var.dynatrace_connection_id])
    )
    error_message = "Trust must be restricted to the Dynatrace AWS principal and this connection's external ID."
  }
}

run "logs_disabled_by_default" {
  command = plan

  assert {
    condition = (
      length(aws_kinesis_firehose_delivery_stream.logs) == 0 &&
      length(aws_cloudwatch_log_account_policy.dynatrace) == 0 &&
      length(aws_s3_bucket.logs_backup) == 0 &&
      length(aws_iam_role.firehose) == 0 &&
      length(aws_iam_role.cloudwatch_logs) == 0 &&
      length(aws_cloudwatch_log_group.firehose) == 0 &&
      length(output.cloudwatch_logs_regions) == 0 &&
      output.cloudwatch_logs_firehose_arn == null
    )
    error_message = "Accounts that do not opt in must have no log-forwarding infrastructure."
  }
}

run "logs_enabled" {
  command = apply

  variables {
    cloudwatch_logs = {
      endpoint_url = "https://abc12345.live.dynatrace.com/api/v2/logs/ingest/aws_firehose"
      secret_arn   = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:logs-AbCdEf"
    }
  }

  assert {
    condition = (
      aws_cloudwatch_log_account_policy.dynatrace["enabled"].scope == "ALL" &&
      aws_cloudwatch_log_account_policy.dynatrace["enabled"].policy_type == "SUBSCRIPTION_FILTER_POLICY" &&
      jsondecode(aws_cloudwatch_log_account_policy.dynatrace["enabled"].policy_document).FilterPattern == "" &&
      jsondecode(aws_cloudwatch_log_account_policy.dynatrace["enabled"].policy_document).DestinationArn == output.cloudwatch_logs_firehose_arn &&
      jsondecode(aws_cloudwatch_log_account_policy.dynatrace["enabled"].policy_document).RoleArn == aws_iam_role.cloudwatch_logs["enabled"].arn &&
      aws_cloudwatch_log_account_policy.dynatrace["enabled"].selection_criteria == "LogGroupName NOT IN [\"/aws/kinesisfirehose/dynatrace-cloudwatch-logs\"]"
    )
    error_message = "All current and future log groups must forward unfiltered to Firehose, excluding only its own delivery logs."
  }

  assert {
    condition = (
      aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].url == var.cloudwatch_logs.endpoint_url &&
      aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].secrets_manager_configuration[0].secret_arn == var.cloudwatch_logs.secret_arn &&
      aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].secrets_manager_configuration[0].enabled &&
      aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].access_key == null &&
      aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].request_configuration[0].content_encoding == "GZIP" &&
      length(aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].processing_configuration) == 0 &&
      aws_kinesis_firehose_delivery_stream.logs["enabled"].http_endpoint_configuration[0].s3_backup_mode == "FailedDataOnly" &&
      !aws_s3_bucket.logs_backup["enabled"].force_destroy &&
      output.cloudwatch_logs_regions == toset(["eu-west-2"])
    )
    error_message = "Delivery must preserve the CloudWatch envelope, read the token at runtime, retain failed deliveries and report only the deployed region."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.cloudwatch_logs["enabled"].policy).Statement[0].Resource == [output.cloudwatch_logs_firehose_arn] &&
      jsondecode(aws_iam_role.cloudwatch_logs["enabled"].assume_role_policy).Statement[0].Condition.StringLike["aws:SourceArn"] == "arn:aws:logs:eu-west-2:123456789012:*" &&
      jsondecode(aws_iam_role_policy.firehose["enabled"].policy).Statement[3].Resource == [var.cloudwatch_logs.secret_arn]
    )
    error_message = "AWS service roles must restrict the source account, destination stream and ingestion secret."
  }
}

run "customer_managed_secret_key" {
  command = plan

  variables {
    cloudwatch_logs = {
      endpoint_url       = "https://abc12345.live.dynatrace.com/api/v2/logs/ingest/aws_firehose"
      secret_arn         = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:logs-AbCdEf"
      secret_kms_key_arn = "arn:aws:kms:eu-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.firehose["enabled"].policy).Statement[4].Resource == [var.cloudwatch_logs.secret_kms_key_arn] &&
      jsondecode(aws_iam_role_policy.firehose["enabled"].policy).Statement[4].Condition.StringEquals["kms:EncryptionContext:SecretARN"] == var.cloudwatch_logs.secret_arn
    )
    error_message = "KMS decrypt access must be scoped to the configured key and ingestion secret."
  }
}

run "reject_wrong_account" {
  command = plan
  variables { account_id = "999999999999" }
  expect_failures = [aws_iam_role.dynatrace]
}

run "reject_secret_in_wrong_region" {
  command = plan
  variables {
    cloudwatch_logs = {
      endpoint_url = "https://abc12345.live.dynatrace.com/api/v2/logs/ingest/aws_firehose"
      secret_arn   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:logs-AbCdEf"
    }
  }
  expect_failures = [aws_kinesis_firehose_delivery_stream.logs]
}

run "reject_incomplete_endpoint" {
  command = plan
  variables {
    cloudwatch_logs = {
      endpoint_url = "https://abc12345.apps.dynatrace.com"
      secret_arn   = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:logs-AbCdEf"
    }
  }
  expect_failures = [var.cloudwatch_logs]
}
