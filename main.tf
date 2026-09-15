module "aws_account_a" {
	source = "./modules/aws-account"

	providers = {
		aws       = aws.account_a
		dynatrace = dynatrace
	}

	account_name = var.aws_account_a_name
	account_id   = var.aws_account_a_id
	role_name    = var.aws_account_a_role_name
	dynatrace_environment_url = var.dynatrace_environment_url
}

module "aws_account_b" {
	count  = var.aws_account_b_enabled ? 1 : 0
	source = "./modules/aws-account"

	providers = {
		aws       = aws.account_b
		dynatrace = dynatrace
	}

	account_name = var.aws_account_b_name
	account_id   = var.aws_account_b_id
	role_name    = var.aws_account_b_role_name
	dynatrace_environment_url = var.dynatrace_environment_url
}
