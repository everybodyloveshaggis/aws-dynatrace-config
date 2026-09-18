locals {
  dynatrace_secret = try(jsondecode(ephemeral.aws_secretsmanager_secret_version.dynatrace.secret_string), {})

  # The secret's postcondition rejects missing/empty values before provider use.
  dynatrace_environment_url = try(local.dynatrace_secret.DYNATRACE_ENV_URL, null)
  dynatrace_platform_token  = try(local.dynatrace_secret.DYNATRACE_PLATFORM_TOKEN, null)
}
