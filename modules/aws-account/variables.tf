variable "account_name" {
  description = "Display name for the AWS account and Dynatrace connection"
  type        = string
}

variable "account_id" {
  description = "12-digit AWS account ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "role_name" {
  description = "IAM role assumed by Dynatrace"
  type        = string
  default     = "DynatraceAwsMonitoringRole"
}

variable "dynatrace_environment_url" {
  description = "Dynatrace environment URL used in the OIDC audience"
  type        = string
}