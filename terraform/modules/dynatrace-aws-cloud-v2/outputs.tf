output "account_id" {
  description = "AWS account represented by this connection."
  value       = var.account_id
}

output "connection_object_id" {
  description = "Complete Dynatrace Settings objectId. Publish through TFC outputs and use unchanged as the IAM trust policy ExternalId."
  value       = dynatrace_aws_connection.this.id
}

output "role_arn" {
  description = "Expected IAM role ARN, available during bootstrap."
  value       = local.role_arn
}

output "role_name" {
  description = "IAM monitoring role name."
  value       = var.role_name
}

output "role_path" {
  description = "IAM monitoring role path."
  value       = var.role_path
}

output "monitoring_configuration_id" {
  description = "Monitoring configuration ID, or null until monitoring is enabled."
  value       = try(dynatrace_hub_extension_v2_config.aws[0].id, null)
}
