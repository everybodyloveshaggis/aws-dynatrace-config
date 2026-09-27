# Production inputs loaded by GitHub Actions with -var-file=env/prd.tfvars.
# Keep credentials in Secrets Manager; this file contains only its ARN.
environment              = "prd"
dynatrace_environment_id = "jew15896"
dynatrace_secret_arn     = "arn:aws:secretsmanager:eu-west-2:899045892145:secret:dynatrace-secrets-sPjhXs"
aws_region               = "eu-west-2"
monitored_regions        = ["eu-west-2", "eu-west-1"]
role_name                = "dynatrace-aws-monitoring-role-v2"
role_path                = "/"


# Keep NEW accounts out of this set until their IAM workspace succeeds.
# After a successful IAM apply for each new account, keep adding ready accounts:
# ready_account_ids = ["111111111111", "222222222222"]
ready_account_ids = ["899045892145"]
