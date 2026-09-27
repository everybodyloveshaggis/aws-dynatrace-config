variable "account_ids_ssm_path" {
  description = "SSM Parameter Store path where account IDs are stored as a comma-separated string."
  type        = string
  default     = "/arecps/accounts/all_account_ids"

  validation {
    condition     = startswith(var.account_ids_ssm_path, "/")
    error_message = "account_ids_ssm_path must be an absolute SSM parameter path."
  }
}

variable "aws_region" {
  description = "Region containing the account inventory SSM parameters."
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "Optional local AWS profile; leave null for TFC dynamic credentials."
  type        = string
  default     = null
}

variable "environment" {
  description = "Account routing for this workspace: dev, tst or prd. Use workspace dynatrace-<environment>-application."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "tst", "prd"], var.environment)
    error_message = "environment must be dev, tst or prd."
  }
}

variable "dynatrace_secret_arn" {
  description = "Secrets Manager ARN for this workspace's tenant; JSON contains DYNATRACE_ENV_URL and DYNATRACE_PLATFORM_TOKEN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.dynatrace_secret_arn))
    error_message = "dynatrace_secret_arn must be a commercial AWS Secrets Manager secret ARN."
  }
}

variable "dynatrace_environment_id" {
  description = "Public Dynatrace tenant ID, such as abc12345, used for the IAM role tag. Must match the credential secret's URL."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.dynatrace_environment_id))
    error_message = "dynatrace_environment_id must be a non-empty tenant ID without a URL or path."
  }
}

variable "ready_account_ids" {
  description = "Accounts whose IAM workspaces have successfully applied the published connection objectId. Keep existing ready accounts when onboarding more accounts."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for id in var.ready_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "ready_account_ids must contain only 12-digit AWS account IDs."
  }
}

variable "role_name" {
  description = "Monitoring role name published to the IAM repo for every account."
  type        = string
  default     = "DynatraceAwsMonitoringRole"

  validation {
    condition     = can(regex("^[A-Za-z0-9_+=,.@-]{1,64}$", var.role_name))
    error_message = "role_name must be a valid IAM role name (1-64 characters)."
  }
}

variable "role_path" {
  description = "Monitoring role path published to the IAM repo, including leading and trailing slashes."
  type        = string
  default     = "/"

  validation {
    condition     = can(regex("^/([!-~]+/)?$", var.role_path)) && length(var.role_path) <= 512
    error_message = "role_path must be / or an IAM path beginning and ending with /, at most 512 characters."
  }
}

variable "monitored_regions" {
  description = "Regions monitored in every account. Defaults to aws_region; us-east-1 is always included for global resources."
  type        = set(string)
  default     = null
}

variable "aws_extension_version" {
  description = "Optional explicit com.dynatrace.extension.da-aws version to install/activate through Terraform. Null uses the tenant's already installed extension. Requires DYNATRACE_API_TOKEN in the secret when set."
  type        = string
  default     = null

  validation {
    condition     = var.aws_extension_version == null ? true : can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.aws_extension_version))
    error_message = "aws_extension_version must be null or a numeric extension version such as 1.0.5."
  }
}
