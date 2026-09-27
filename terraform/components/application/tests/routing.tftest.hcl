# Run through tests/test_application.py. Terraform 1.15 cannot mock ephemeral
# resources, so that harness supplies a localhost Secrets Manager endpoint.
mock_provider "aws" {}

provider "aws" {
  alias                       = "dynatrace_secrets"
  region                      = "eu-west-2"
  access_key                  = "test-only-access-key"
  secret_key                  = "test-only-secret-key"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    secretsmanager = var.secrets_manager_endpoint
  }
}

mock_provider "dynatrace" {
  mock_data "dynatrace_hub_extension_v2_active_version" {
    defaults = { active_version = "1.0.5" }
  }
}

mock_provider "dynatrace" {
  alias = "extension_installation"
}

variables {
  secrets_manager_endpoint = "http://127.0.0.1:1"
  dynatrace_secret_arn     = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:test-AbCdEf"
  dynatrace_environment_id = "example"
  account_ids_ssm_path     = "/test/accounts"
  environment              = "dev"
}

override_data {
  target = data.aws_ssm_parameter.account_ids
  values = {
    type           = "StringList"
    insecure_value = " 111111111111,222222222222,333333333333,444444444444,111111111111, ,"
  }
}

override_data {
  target = data.aws_ssm_parameter.dev_accounts
  values = {
    type           = "String"
    insecure_value = " 111111111111,111111111111, "
  }
}

override_data {
  target = data.aws_ssm_parameter.tst_accounts
  values = {
    type           = "StringList"
    insecure_value = "222222222222, "
  }
}

run "bootstrap_dev" {
  command = apply

  assert {
    condition = (
      output.accounts_map.dev.accounts == toset(["111111111111"]) &&
      output.accounts_map.tst.accounts == toset(["222222222222"]) &&
      output.accounts_map.prd.accounts == toset(["333333333333", "444444444444"]) &&
      toset(keys(output.aws_connections)) == toset(["111111111111"])
    )
    error_message = "SSM lists must be trimmed and deduplicated, with only dev accounts created in dev."
  }

  assert {
    condition = (
      output.aws_connections["111111111111"].environment == "dev" &&
      output.aws_connections["111111111111"].dynatrace_environment_id == "example" &&
      output.aws_connections["111111111111"].role_arn == "arn:aws:iam::111111111111:role/DynatraceAwsMonitoringRole" &&
      length(output.aws_connections["111111111111"].object_id) > 0 &&
      output.monitoring_configuration_ids["111111111111"] == null
    )
    error_message = "Bootstrap must publish the IAM contract and defer monitoring until IAM is ready."
  }

  assert {
    condition = (
      data.aws_ssm_parameter.account_ids.name == "/test/accounts" &&
      data.aws_ssm_parameter.dev_accounts.name == "/arecps/dynatrace/dev_accounts" &&
      data.aws_ssm_parameter.tst_accounts.name == "/arecps/dynatrace/tst_accounts" &&
      !data.aws_ssm_parameter.account_ids.with_decryption &&
      !data.aws_ssm_parameter.dev_accounts.with_decryption &&
      !data.aws_ssm_parameter.tst_accounts.with_decryption
    )
    error_message = "The component must read the intended public SSM inventories without decryption."
  }
}

run "activate_dev" {
  command = apply

  variables { ready_account_ids = ["111111111111"] }

  assert {
    condition = (
      output.aws_connections["111111111111"].object_id == run.bootstrap_dev.aws_connections["111111111111"].object_id &&
      output.monitoring_configuration_ids["111111111111"] != null
    )
    error_message = "Activating IAM-ready accounts must preserve the external ID already published to IAM."
  }
}

run "route_tst" {
  command = apply

  variables { environment = "tst" }

  assert {
    condition = (
      toset(keys(output.aws_connections)) == toset(["222222222222"]) &&
      output.aws_connections["222222222222"].environment == "tst" &&
      output.monitoring_configuration_ids["222222222222"] == null
    )
    error_message = "The tst workspace must manage only accounts in the tst inventory."
  }
}

run "route_prd" {
  command = apply

  variables { environment = "prd" }

  assert {
    condition = (
      toset(keys(output.aws_connections)) == toset(["333333333333", "444444444444"]) &&
      alltrue([for connection in output.aws_connections : connection.environment == "prd"])
    )
    error_message = "The prd workspace must receive all remaining accounts after dev/tst exclusion."
  }
}

run "install_extension_once_per_tenant" {
  command = apply

  variables {
    environment           = "prd"
    ready_account_ids     = ["333333333333", "444444444444"]
    aws_extension_version = "1.0.5"
  }

  assert {
    condition = (
      length(dynatrace_hub_extension_active_version.aws) == 1 &&
      dynatrace_hub_extension_active_version.aws[0].name == "com.dynatrace.extension.da-aws" &&
      dynatrace_hub_extension_active_version.aws[0].version == "1.0.5" &&
      length(output.monitoring_configuration_ids) == 2 &&
      alltrue([for id in output.monitoring_configuration_ids : id != null])
    )
    error_message = "One tenant extension installation must support monitoring in multiple ready accounts."
  }
}

run "empty_classifications_send_all_to_prd" {
  command = apply

  variables { environment = "prd" }

  override_data {
    target = data.aws_ssm_parameter.dev_accounts
    values = { type = "String", insecure_value = " , " }
  }
  override_data {
    target = data.aws_ssm_parameter.tst_accounts
    values = { type = "String", insecure_value = " " }
  }

  assert {
    condition     = toset(keys(output.aws_connections)) == toset(["111111111111", "222222222222", "333333333333", "444444444444"])
    error_message = "Empty dev/tst classifications must leave all inventory accounts in prd."
  }
}

run "empty_dev_creates_no_connections" {
  command = apply

  override_data {
    target = data.aws_ssm_parameter.dev_accounts
    values = { type = "String", insecure_value = "" }
  }

  assert {
    condition     = length(output.aws_connections) == 0 && length(output.monitoring_configuration_ids) == 0
    error_message = "An empty dev inventory must create no connections."
  }
}

run "reject_malformed_inventory" {
  command = plan

  # The malformed account is in prd, avoiding a child input validation masking
  # the root routing guard under test in this dev run.
  override_data {
    target = data.aws_ssm_parameter.account_ids
    values = { type = "String", insecure_value = "111111111111,222222222222,invalid" }
  }

  expect_failures = [terraform_data.account_routing]
}

run "reject_overlapping_classifications" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.tst_accounts
    values = { type = "String", insecure_value = "111111111111,222222222222" }
  }

  expect_failures = [terraform_data.account_routing]
}

run "reject_classification_outside_inventory" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.tst_accounts
    values = { type = "String", insecure_value = "555555555555" }
  }

  expect_failures = [terraform_data.account_routing]
}

run "reject_ready_account_in_another_environment" {
  command = plan

  variables { ready_account_ids = ["222222222222"] }

  expect_failures = [terraform_data.account_routing]
}

run "reject_encrypted_inventory" {
  command = plan

  override_data {
    target = data.aws_ssm_parameter.account_ids
    values = {
      type           = "SecureString"
      insecure_value = "111111111111,222222222222"
    }
  }

  expect_failures = [data.aws_ssm_parameter.account_ids]
}
