mock_provider "dynatrace" {
  mock_resource "dynatrace_aws_connection" {
    defaults = {
      id = "complete-settings-object-id-preserved-for-iam-external-id"
    }
  }

  mock_data "dynatrace_hub_extension_v2_active_version" {
    defaults = {
      active_version = "1.0.5"
    }
  }
}

variables {
  account_id        = "123456789012"
  deployment_region = "eu-west-2"
  monitored_regions = ["eu-west-2"]
}

run "bootstrap_connection_only" {
  command = apply

  assert {
    condition = (
      output.connection_object_id == "complete-settings-object-id-preserved-for-iam-external-id" &&
      dynatrace_aws_connection.this.name == "aws-123456789012" &&
      output.role_arn == "arn:aws:iam::123456789012:role/DynatraceAwsMonitoringRole"
    )
    error_message = "Bootstrap must publish the full objectId and deterministic role ARN before IAM exists."
  }

  assert {
    condition = (
      length(dynatrace_aws_connection_role_arn.this) == 0 &&
      length(data.dynatrace_hub_extension_v2_active_version.aws) == 0 &&
      length(dynatrace_hub_extension_v2_config.aws) == 0 &&
      output.monitoring_configuration_id == null
    )
    error_message = "Bootstrap must not associate the role, read the installed extension, or create monitoring."
  }

  assert {
    condition = (
      dynatrace_aws_connection.this.role_based_auth[0].consumers == toset(["SVC:com.dynatrace.da"]) &&
      length(dynatrace_aws_connection.this.web_identity) == 0
    )
    error_message = "The AWS connection must use role-based data acquisition authentication."
  }
}

run "activate_existing_connection" {
  command = apply

  variables {
    enable_monitoring = true
    account_name      = "development"
    role_name         = "Monitoring"
    role_path         = "/observability/dynatrace/"
  }

  assert {
    condition = (
      output.connection_object_id == run.bootstrap_connection_only.connection_object_id &&
      dynatrace_aws_connection_role_arn.this[0].aws_connection_id == output.connection_object_id &&
      dynatrace_aws_connection_role_arn.this[0].role_arn == "arn:aws:iam::123456789012:role/observability/dynatrace/Monitoring" &&
      dynatrace_aws_connection.this.name == "development" &&
      output.monitoring_configuration_id != null
    )
    error_message = "Activation must retain the bootstrap objectId and associate the agreed role path and name."
  }

  assert {
    condition = (
      dynatrace_hub_extension_v2_config.aws[0].scope == "integration-aws" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).version == "1.0.5" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.credentials[0].connectionId == output.connection_object_id &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.credentials[0].accountId == "123456789012" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.regionFiltering == ["eu-west-2", "us-east-1"] &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.metricsConfiguration.regions == ["eu-west-2", "us-east-1"]
    )
    error_message = "Monitoring must bind this account and objectId, use the installed extension version, and include global regions."
  }

  assert {
    condition = (
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.deploymentMode == "MANUAL" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.deploymentScope == "SINGLE_ACCOUNT" &&
      jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.manualDeploymentStatus == "COMPLETE" &&
      !jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.cloudWatchLogsConfiguration.enabled &&
      length(jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.cloudWatchLogsConfiguration.regions) == 0
    )
    error_message = "Monitoring must record Terraform's manual single-account deployment, with log forwarding disabled."
  }
}

run "deduplicate_regions" {
  command = plan

  variables {
    enable_monitoring = true
    deployment_region = "us-east-1"
    monitored_regions = ["us-west-2", "us-east-1", "us-west-2"]
  }

  assert {
    condition     = jsondecode(dynatrace_hub_extension_v2_config.aws[0].value).aws.regionFiltering == ["us-east-1", "us-west-2"]
    error_message = "Region filtering must be sorted and contain us-east-1 exactly once."
  }
}

run "reject_unmonitored_deployment_region" {
  command = plan

  variables {
    enable_monitoring = true
    deployment_region = "eu-west-1"
  }

  expect_failures = [dynatrace_hub_extension_v2_config.aws[0]]
}

run "reject_invalid_account" {
  command = plan

  variables {
    account_id = "12345678901"
  }

  expect_failures = [var.account_id]
}

run "reject_empty_account_name" {
  command = plan

  variables {
    account_name = " "
  }

  expect_failures = [var.account_name]
}

run "reject_invalid_role_name" {
  command = plan

  variables {
    role_name = "invalid/name"
  }

  expect_failures = [var.role_name]
}

run "reject_invalid_role_path" {
  command = plan

  variables {
    role_path = "observability/"
  }

  expect_failures = [var.role_path]
}

run "reject_empty_regions" {
  command = plan

  variables {
    monitored_regions = []
  }

  expect_failures = [var.monitored_regions]
}

run "reject_invalid_region" {
  command = plan

  variables {
    monitored_regions = ["not-a-region"]
  }

  expect_failures = [var.monitored_regions]
}

run "reject_noncommercial_deployment_region" {
  command = plan

  variables {
    deployment_region = "cn-north-1"
  }

  expect_failures = [var.deployment_region]
}
