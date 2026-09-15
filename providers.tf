terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.0"
    }
  }

  cloud {
    organization = "smdevops96_org"

    workspaces {
      name = "aws-dynatrace-config"
    }
  }
}

provider "dynatrace" {
  dt_env_url    = local.dynatrace_environment_url
  platform_token = local.dynatrace_platform_token
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_secretsmanager_secret_version" "dynatrace" {
  secret_id = var.dynatrace_secret_arn
}

locals {
  dynatrace_secret = jsondecode(data.aws_secretsmanager_secret_version.dynatrace.secret_string)

  dynatrace_environment_url = try(local.dynatrace_secret.DYNATRACE_ENV_URL, "")
  dynatrace_platform_token  = try(local.dynatrace_secret.DYNATRACE_PLATFORM_TOKEN, "")
}
