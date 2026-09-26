# Ephemeral reads keep secret values out of Terraform state and saved plans.
ephemeral "aws_secretsmanager_secret_version" "dynatrace" {
  provider  = aws.dynatrace_secrets
  secret_id = var.dynatrace_secret_arn

  lifecycle {
    postcondition {
      condition = try(
        can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$", jsondecode(self.secret_string).DYNATRACE_ENV_URL)) &&
        split(".", trimprefix(jsondecode(self.secret_string).DYNATRACE_ENV_URL, "https://"))[0] == var.dynatrace_environment_id &&
        jsondecode(self.secret_string).DYNATRACE_PLATFORM_TOKEN == tostring(jsondecode(self.secret_string).DYNATRACE_PLATFORM_TOKEN) &&
        length(trimspace(jsondecode(self.secret_string).DYNATRACE_PLATFORM_TOKEN)) > 0,
        false
      )
      error_message = "The Dynatrace secret must be a JSON object containing an HTTPS DYNATRACE_ENV_URL (without a path) matching dynatrace_environment_id and a non-empty DYNATRACE_PLATFORM_TOKEN."
    }
    postcondition {
      condition = var.aws_extension_version == null ? true : try(
        jsondecode(self.secret_string).DYNATRACE_API_TOKEN == tostring(jsondecode(self.secret_string).DYNATRACE_API_TOKEN) &&
        length(trimspace(jsondecode(self.secret_string).DYNATRACE_API_TOKEN)) > 0,
        false
      )
      error_message = "Installing an AWS extension version requires a non-empty classic DYNATRACE_API_TOKEN in the secret."
    }
  }
}
