output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_role_arn" {
  value = module.infrastructure.role_arn
}

output "dynatrace_connection_id" {
  value = module.application.dynatrace_connection_id
}

output "dynatrace_monitoring_configuration_id" {
  value = module.application.dynatrace_monitoring_configuration_id
}

output "cloudwatch_logs_firehose_arn" {
  description = "CloudWatch log delivery stream ARN, or null when log forwarding is disabled"
  value       = module.infrastructure.cloudwatch_logs_firehose_arn
}

output "cloudwatch_logs_backup_bucket" {
  description = "S3 bucket containing failed log deliveries, or null when disabled"
  value       = module.infrastructure.cloudwatch_logs_backup_bucket
}
