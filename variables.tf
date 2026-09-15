variable "dynatrace_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Dynatrace credentials"
  type        = string
  default     = "arn:aws:secretsmanager:eu-west-2:899045892145:secret:dynatrace-secrets-sPjhXs"
}

variable "aws_region" {
  description = "Region for the AWS account mapped to this Terraform Cloud workspace"
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "Optional local AWS CLI profile; leave null when Terraform Cloud supplies AWS credentials"
  type        = string
  default     = null
}

variable "aws_role_name" {
  description = "IAM role name created in the current AWS account"
  type        = string
  default     = "DynatraceAwsMonitoringRole"
}
