# Preserve the existing single-account production deployment during the split.
# These moves are inert in workspaces that never had module.application.
moved {
  from = module.application.dynatrace_aws_connection.this
  to   = module.aws_connections["899045892145"].dynatrace_aws_connection.this
}

moved {
  from = module.application.dynatrace_aws_connection_role_arn.this
  to   = module.aws_connections["899045892145"].dynatrace_aws_connection_role_arn.this[0]
}

moved {
  from = module.application.dynatrace_hub_extension_v2_config.aws
  to   = module.aws_connections["899045892145"].dynatrace_hub_extension_v2_config.aws[0]
}

# Release AWS ownership without deleting deployed IAM or log resources.
# Adopt the monitoring role in the IAM repo as described in MIGRATION.md.
# Existing log resources need separate ownership or deliberate retirement.
removed {
  from = module.infrastructure

  lifecycle {
    destroy = false
  }
}
