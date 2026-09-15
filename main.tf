data "aws_caller_identity" "current" {}

module "aws_account" {
  source = "./modules/aws-account"

	providers = {
		aws       = aws
		dynatrace = dynatrace
	}

	account_name              = "aws-${data.aws_caller_identity.current.account_id}"
	account_id                = data.aws_caller_identity.current.account_id
	role_name                 = var.aws_role_name
	dynatrace_environment_url = local.dynatrace_environment_url
}
