terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = ">= 1.104.1, < 2.0"
    }
  }

  # Select dynatrace-dev-application, dynatrace-tst-application or
  # dynatrace-prd-application through TF_WORKSPACE.
  # Set each HCP workspace's Terraform Working Directory separately to
  # terraform/components/application so CLI uploads include sibling modules.
  cloud {
    organization = "smdevops96_org"

    workspaces {
      tags = ["dynatrace", "application"]
    }
  }
}
