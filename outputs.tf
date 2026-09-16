output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_role_arn" {
  value = module.aws_account.role_arn
}

output "dynatrace_connection_id" {
  value = module.aws_account.dynatrace_connection_id
}

output "dynatrace_monitoring_configuration_id" {
  value = module.aws_account.dynatrace_monitoring_configuration_id
}
