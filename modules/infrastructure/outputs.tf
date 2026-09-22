output "role_arn" {
  value      = aws_iam_role.dynatrace.arn
  depends_on = [aws_iam_role_policy_attachment.read_only]
}

output "cloudwatch_logs_regions" {
  value      = var.cloudwatch_logs == null ? toset([]) : toset([data.aws_region.current.name])
  depends_on = [aws_cloudwatch_log_account_policy.dynatrace]
}

output "cloudwatch_logs_firehose_arn" {
  value = try(aws_kinesis_firehose_delivery_stream.logs["enabled"].arn, null)
}

output "cloudwatch_logs_backup_bucket" {
  value = try(aws_s3_bucket.logs_backup["enabled"].id, null)
}
