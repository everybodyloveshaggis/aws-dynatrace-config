

mock_provider "dynatrace" {
  mock_data "dynatrace_hub_extension_v2_active_version" {
    defaults = {
      active_version = "1.0.5"
    }
  }
}

variables {
  role_arn          = "arn:aws:iam::123456789012:role/DynatraceAwsMonitoringRole"
  account_name      = "aws-123456789012"
  account_id        = "123456789012"
  deployment_region = "eu-west-2"
  monitored_regions = ["eu-west-2"]
}

run "monitoring_connection" {
  command = apply

  assert {
    condition = (
      dynatrace_aws_connection_role_arn.this.role_arn == var.role_arn &&
      !jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.cloudWatchLogsConfiguration.enabled &&
      length(jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.cloudWatchLogsConfiguration.regions) == 0
    )
    error_message = "The application must link the supplied AWS role and disable logs by default."
  }

  assert {
    condition     = dynatrace_aws_connection.this.role_based_auth[0].consumers == toset(["SVC:com.dynatrace.da"]) && length(dynatrace_aws_connection.this.web_identity) == 0
    error_message = "Monitoring must use the data acquisition service and cross-account authentication."
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


run "reject_empty_regions" {
  command = plan

  variables {
    monitored_regions = []
  }

  expect_failures = [var.monitored_regions]
}

run "cloudwatch_logs_enabled" {
  command = plan

  variables {
    cloudwatch_logs_regions = ["eu-west-2"]
  }

  assert {
    condition = (
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.cloudWatchLogsConfiguration.enabled &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.cloudWatchLogsConfiguration.regions == ["eu-west-2"] &&
      jsondecode(dynatrace_hub_extension_v2_config.aws.value).aws.deploymentMode == "MANUAL"
    )
    error_message = "Logs must be enabled only in regions where Terraform deploys forwarding, without automated CloudFormation deployment."
  }
}
