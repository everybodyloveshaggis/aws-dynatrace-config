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

variable "dynatrace_connection_id" {
  description = "Dynatrace connection ID used as the monitoring role's external ID"
  type        = string
}
