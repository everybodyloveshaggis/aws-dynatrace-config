terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }

    dynatrace = {
      source = "dynatrace-oss/dynatrace"
      version = "~> 1.0"
    }
  }
}