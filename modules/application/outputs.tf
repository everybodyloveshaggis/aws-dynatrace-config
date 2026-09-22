output "account_id" {
  value = var.account_id
}

output "dynatrace_connection_id" {
  value = dynatrace_aws_connection.this.id
}

output "dynatrace_monitoring_configuration_id" {
  value = dynatrace_hub_extension_v2_config.aws.id
}
