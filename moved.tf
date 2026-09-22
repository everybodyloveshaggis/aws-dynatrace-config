# Preserve existing remote objects when separating provider responsibilities.
moved {
  from = module.aws_account.dynatrace_aws_connection.this
  to   = module.application.dynatrace_aws_connection.this
}

moved {
  from = module.aws_account.dynatrace_aws_connection_role_arn.this
  to   = module.application.dynatrace_aws_connection_role_arn.this
}

moved {
  from = module.aws_account.dynatrace_hub_extension_v2_config.aws
  to   = module.application.dynatrace_hub_extension_v2_config.aws
}

moved {
  from = module.aws_account.aws_iam_role.dynatrace
  to   = module.infrastructure.aws_iam_role.dynatrace
}

moved {
  from = module.aws_account.aws_iam_role_policy_attachment.read_only
  to   = module.infrastructure.aws_iam_role_policy_attachment.read_only
}
