data "aws_caller_identity" "current" {}

module "application" {
  source = "./modules/application"

  providers = {
    dynatrace = dynatrace
  }

  account_name            = "aws-${data.aws_caller_identity.current.account_id}"
  account_id              = data.aws_caller_identity.current.account_id
  role_arn                = module.infrastructure.role_arn
  deployment_region       = var.aws_region
  monitored_regions       = var.monitored_regions == null ? [var.aws_region] : var.monitored_regions
  cloudwatch_logs_regions = module.infrastructure.cloudwatch_logs_regions
}

module "infrastructure" {
  source = "./modules/infrastructure"

  providers = {
    aws = aws
  }

  account_id              = data.aws_caller_identity.current.account_id
  role_name               = var.aws_role_name
  dynatrace_connection_id = module.application.dynatrace_connection_id
  cloudwatch_logs         = var.cloudwatch_logs
}
