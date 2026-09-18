# Ephemeral reads keep secret values out of Terraform state and saved plans.
ephemeral "aws_secretsmanager_secret_version" "dynatrace" {
  provider  = aws.dynatrace_secrets
  secret_id = var.dynatrace_secret_arn

  lifecycle {
    postcondition {
      condition = try(
        can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$", jsondecode(self.secret_string).DYNATRACE_ENV_URL)) &&
        jsondecode(self.secret_string).DYNATRACE_PLATFORM_TOKEN == tostring(jsondecode(self.secret_string).DYNATRACE_PLATFORM_TOKEN) &&
        length(trimspace(jsondecode(self.secret_string).DYNATRACE_PLATFORM_TOKEN)) > 0,
        false
      )
      error_message = "The Dynatrace secret must be a JSON object containing an HTTPS DYNATRACE_ENV_URL (without a path) and a non-empty DYNATRACE_PLATFORM_TOKEN."
    }
  }
}
