variable "cloudwatch_logs" {
  description = "Set to enable forwarding all CloudWatch log groups in the provider region; null disables it. The secret must contain an api_key with a Dynatrace logs.ingest token."
  type = object({
    endpoint_url          = string
    secret_arn            = string
    secret_kms_key_arn    = optional(string)
    name                  = optional(string, "dynatrace-cloudwatch-logs")
    backup_retention_days = optional(number, 30)
  })
  default = null

  validation {
    condition = var.cloudwatch_logs == null ? true : can(regex(
      "^https://[A-Za-z0-9.-]+(/e/[A-Za-z0-9-]+)?/api/v2/logs/ingest/aws_firehose$",
      var.cloudwatch_logs.endpoint_url
    ))
    error_message = "endpoint_url must be the full HTTPS Dynatrace /api/v2/logs/ingest/aws_firehose endpoint (port 443)."
  }

  validation {
    condition = var.cloudwatch_logs == null ? true : can(regex(
      "^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.cloudwatch_logs.secret_arn
    ))
    error_message = "secret_arn must be an AWS Secrets Manager secret ARN."
  }

  validation {
    condition     = var.cloudwatch_logs == null ? true : can(regex("^[a-z][a-z0-9-]{0,37}$", var.cloudwatch_logs.name))
    error_message = "name must contain 1-38 lowercase letters, digits or hyphens and start with a letter."
  }

  validation {
    condition = var.cloudwatch_logs == null ? true : (
      var.cloudwatch_logs.backup_retention_days >= 1 &&
      floor(var.cloudwatch_logs.backup_retention_days) == var.cloudwatch_logs.backup_retention_days
    )
    error_message = "backup_retention_days must be a positive whole number."
  }
}
