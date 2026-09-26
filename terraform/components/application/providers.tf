provider "dynatrace" {
  dt_env_url     = local.dynatrace_environment_url
  platform_token = local.dynatrace_platform_token
}

# Keep classic installation credentials separate so settings always use the
# platform token and retain the service user's ownership/permissions.
provider "dynatrace" {
  alias        = "extension_installation"
  dt_env_url   = local.dynatrace_environment_url
  dt_api_token = var.aws_extension_version == null ? null : try(local.dynatrace_secret.DYNATRACE_API_TOKEN, null)
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Use the same runner identity, but read the secret in its own AWS region.
provider "aws" {
  alias   = "dynatrace_secrets"
  region  = split(":", var.dynatrace_secret_arn)[3]
  profile = var.aws_profile
}
