variable "dt_platform_token" {
  description = "Dynatrace platform token for authentication"
  type        = string
  sensitive   = true
}

variable "dynatrace_environment_url" {
  description = "Dynatrace environment URL"
  type        = string
}

variable "aws_account_a_name" {
  description = "Display name for the first AWS account"
  type        = string
}

variable "aws_account_a_id" {
  description = "12-digit AWS account ID for the first account"
  type        = string
}

variable "aws_account_a_region" {
  description = "AWS region used by the first account provider"
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_a_profile" {
  description = "Optional local AWS CLI profile for the first account"
  type        = string
  default     = null
}

variable "aws_account_a_role_name" {
  description = "IAM role name created in the first account"
  type        = string
  default     = "DynatraceAwsMonitoringRole"
}

variable "aws_account_b_enabled" {
  description = "Whether to configure the second AWS account"
  type        = bool
  default     = false
}

variable "aws_account_b_name" {
  description = "Display name for the second AWS account"
  type        = string
  default     = ""
}

variable "aws_account_b_id" {
  description = "12-digit AWS account ID for the second account"
  type        = string
  default     = ""
}

variable "aws_account_b_region" {
  description = "AWS region used by the second account provider"
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_b_profile" {
  description = "Optional local AWS CLI profile for the second account"
  type        = string
  default     = null
}

variable "aws_account_b_role_name" {
  description = "IAM role name created in the second account"
  type        = string
  default     = "DynatraceAwsMonitoringRole"
}