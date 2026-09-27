output "accounts_map" {
  description = "SSM account routing after whitespace removal, deduplication and validation."
  value       = local.accounts_map
}

# Public metadata only: deliberately nonsensitive so tfe_outputs can expose it
# without granting access to secrets or the complete state snapshot.
output "aws_connections" {
  description = "Account-ID-keyed contract for this environment. object_id is the complete Dynatrace Settings objectId / STS ExternalId."
  value = {
    for account_id, connection in module.aws_connections : account_id => {
      object_id                = connection.connection_object_id
      environment              = var.environment
      dynatrace_environment_id = var.dynatrace_environment_id
      role_name                = var.role_name
      role_path                = var.role_path
      role_arn                 = connection.role_arn
    }
  }
}

output "monitoring_configuration_ids" {
  description = "Account monitoring configuration IDs; null until the account is ready."
  value = {
    for account_id, connection in module.aws_connections : account_id => connection.monitoring_configuration_id
  }
}
