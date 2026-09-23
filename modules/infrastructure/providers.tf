terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}
