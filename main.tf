data "aws_caller_identity" "current" {}

module "aws_account" {
  source = "./modules/application"

  providers = {
    aws       = aws
    dynatrace = dynatrace
  }

  account_name      = "aws-${data.aws_caller_identity.current.account_id}"
  account_id        = data.aws_caller_identity.current.account_id
  role_name         = var.aws_role_name
  deployment_region = var.aws_region
  monitored_regions = var.monitored_regions == null ? [var.aws_region] : var.monitored_regions
}
