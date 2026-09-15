output "account_id" {
  value = var.account_id
}

output "role_arn" {
  value = aws_iam_role.dynatrace.arn
}

output "dynatrace_connection_id" {
  value = dynatrace_aws_connection.this.id
}