output "aws_account_a_role_arn" {
  value = module.aws_account_a.role_arn
}

output "aws_account_a_dynatrace_connection_id" {
  value = module.aws_account_a.dynatrace_connection_id
}

output "aws_account_b_role_arn" {
  value = var.aws_account_b_enabled ? module.aws_account_b[0].role_arn : null
}

output "aws_account_b_dynatrace_connection_id" {
  value = var.aws_account_b_enabled ? module.aws_account_b[0].dynatrace_connection_id : null
}
