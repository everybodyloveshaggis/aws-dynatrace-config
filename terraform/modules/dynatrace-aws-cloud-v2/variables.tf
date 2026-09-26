variable "account_id" {
  description = "12-digit AWS account ID in the commercial aws partition."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "account_name" {
  description = "Display name for the connection. Defaults to aws-<account_id>."
  type        = string
  default     = null

  validation {
    condition     = var.account_name == null ? true : length(trimspace(var.account_name)) > 0
    error_message = "account_name must be null or a non-empty display name."
  }
}

variable "role_name" {
  description = "Monitoring role name created by the separate IAM repository. Keep fixed after activation."
  type        = string
  default     = "DynatraceAwsMonitoringRole"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,64}$", var.role_name))
    error_message = "role_name must contain 1 to 64 IAM role name characters: letters, digits, _, +, =, comma, period, @, or -."
  }
}

variable "role_path" {
  description = "IAM role path, identical to the IAM repository setting. Keep fixed after activation."
  type        = string
  default     = "/"
  nullable    = false

  validation {
    condition     = length(var.role_path) <= 512 && can(regex("^(/|/[\\x21-\\x7E]+/)$", var.role_path))
    error_message = "role_path must be / or a path beginning and ending with /, with printable non-space ASCII characters and at most 512 characters."
  }
}

variable "deployment_region" {
  description = "Commercial AWS deployment region recorded by the manual monitoring configuration."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.deployment_region)) && !startswith(var.deployment_region, "cn-")
    error_message = "deployment_region must be a commercial AWS region name, such as eu-west-2."
  }
}

variable "monitored_regions" {
  description = "Commercial AWS regions to monitor. us-east-1 is always included for global resources."
  type        = set(string)
  nullable    = false

  validation {
    condition = length(var.monitored_regions) > 0 && alltrue([
      for region in var.monitored_regions : can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", region)) && !startswith(region, "cn-")
    ])
    error_message = "monitored_regions must contain at least one commercial AWS region name, such as eu-west-2."
  }
}

variable "enable_monitoring" {
  description = "Set true only after the separate IAM workspace has applied the role and policies using this connection's objectId."
  type        = bool
  default     = false
  nullable    = false
}
