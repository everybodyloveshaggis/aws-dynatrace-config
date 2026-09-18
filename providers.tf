terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
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
  dt_env_url     = local.dynatrace_environment_url
  platform_token = local.dynatrace_platform_token
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Use the same runner identity, but read the secret in its own AWS region.
provider "aws" {
  alias   = "dynatrace_secrets"
  region  = split(":", var.dynatrace_secret_arn)[3]
  profile = var.aws_profile
}
