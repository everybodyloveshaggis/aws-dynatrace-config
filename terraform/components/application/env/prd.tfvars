# Production inputs loaded by GitHub Actions with -var-file=env/prd.tfvars.
# Keep credentials in Secrets Manager; this file contains only its ARN.
environment              = "prd"
dynatrace_environment_id = "jew15896"
dynatrace_secret_arn     = "arn:aws:secretsmanager:eu-west-2:899045892145:secret:dynatrace-secrets-sPjhXs"
aws_region               = "eu-west-2"
monitored_regions        = ["eu-west-2", "eu-west-1"]
role_name                = "DynatraceAwsMonitoringRole"
role_path                = "/"

# This account already has a working connection and monitoring role in the
# legacy state. Preserve its activation while migrating the resource addresses.
ready_account_ids = ["899045892145"]
# Keep NEW accounts out of this set until their IAM workspace succeeds.
# After a successful IAM apply for each new account, keep adding ready accounts:
# ready_account_ids = ["111111111111", "222222222222"]

# Set to an available AWS extension version for Terraform-managed installation.
# Requires DYNATRACE_API_TOKEN in addition to DYNATRACE_PLATFORM_TOKEN.
# aws_extension_version = "<available-version>"
