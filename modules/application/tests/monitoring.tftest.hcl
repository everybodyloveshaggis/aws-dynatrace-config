mock_provider "aws" {
  # Keep the mocked JSON valid for the IAM role's provider-side validation.
  # The assertions below inspect the configured trust statements themselves.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

mock_provider "dynatrace" {
  mock_data "dynatrace_hub_extension_v2_active_version" {
    defaults = {
      active_version = "1.0.5"
    }
  }
}

variables {
  account_name      = "aws-123456789012"
  account_id        = "123456789012"
  deployment_region = "eu-west-2"
  monitored_regions = ["eu-west-2"]
}

run "monitoring_connection" {
  command = apply

  assert {
    condition     = dynatrace_aws_connection.this.role_based_auth[0].consumers == toset(["SVC:com.dynatrace.da"]) && length(dynatrace_aws_connection.this.web_identity) == 0
    error_message = "Monitoring must use the data acquisition service and cross-account authentication."
  }

  assert {
    condition = (
      data.aws_iam_policy_document.assume_role.statement[0].actions == toset(["sts:AssumeRole"]) &&
      one(data.aws_iam_policy_document.assume_role.statement[0].principals).type == "AWS" &&
      one(data.aws_iam_policy_document.assume_role.statement[0].principals).identifiers == toset(["arn:aws:iam::314146291599:root"]) &&
      one(data.aws_iam_policy_document.assume_role.statement[0].condition).test == "StringEquals" &&
      one(data.aws_iam_policy_document.assume_role.statement[0].condition).variable == "sts:ExternalId" &&
      toset(one(data.aws_iam_policy_document.assume_role.statement[0].condition).values) == toset([dynatrace_aws_connection.this.id])
    )
    error_message = "Trust must be restricted to the Dynatrace AWS principal and this connection's external ID."
  }

  assert {
    condition = (
      dynatrace_hub_extension_v2_config.aws.scope == "integration-aws" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).version == "1.0.5" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.credentials[0].connectionId == dynatrace_aws_connection.this.id &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.credentials[0].accountId == "123456789012" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.regionFiltering == ["eu-west-2", "us-east-1"] &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.metricsConfiguration.regions == ["eu-west-2", "us-east-1"]
    )
    error_message = "Monitoring must bind this account and connection, use the installed version, and include global resources in both region lists."
  }
}

run "custom_regions" {
  command = plan

  variables {
    monitored_regions = ["us-west-2", "us-east-1", "us-west-2"]
  }

  assert {
    condition     = jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.regionFiltering == ["us-east-1", "us-west-2"]
    error_message = "Custom regions must be honored without duplicate global regions."
  }
}

run "reject_wrong_account" {
  command = plan

  variables {
    account_id = "999999999999"
  }

  expect_failures = [aws_iam_role.dynatrace]
}

run "reject_empty_regions" {
  command = plan

  variables {
    monitored_regions = []
  }

  expect_failures = [var.monitored_regions]
}
