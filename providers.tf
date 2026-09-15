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
  environment_url = var.dynatrace_environment_url
  api_token       = var.dt_platform_token
}

provider "aws" {
  alias   = "account_a"
  region  = var.aws_account_a_region
  profile = var.aws_account_a_profile
}

provider "aws" {
  alias   = "account_b"
  region  = var.aws_account_b_region
  profile = var.aws_account_b_profile
}