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

variable "deployment_region" {
  description = "AWS deployment region recorded by the manual monitoring configuration"
  type        = string
}

variable "monitored_regions" {
  description = "AWS regions to monitor; us-east-1 is always included for global resources"
  type        = set(string)

  validation {
    condition     = length(var.monitored_regions) > 0 && alltrue([for region in var.monitored_regions : can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", region))])
    error_message = "monitored_regions must contain at least one AWS region name, such as eu-west-2."
  }
}
