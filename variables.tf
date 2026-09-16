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

variable "monitored_regions" {
  description = "AWS regions to monitor; defaults to aws_region, with us-east-1 always added for global resources"
  type        = set(string)
  default     = null
}

variable "aws_role_name" {
  description = "IAM role name created in the current AWS account"
  type        = string
  default     = "DynatraceAwsMonitoringRole"
}
