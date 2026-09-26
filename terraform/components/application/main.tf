# Fail at plan time for invalid inventories instead of silently choosing a tenant.
resource "terraform_data" "account_routing" {
  input = local.accounts_map

  lifecycle {
    precondition {
      condition     = terraform.workspace == "default" || terraform.workspace == "dynatrace-${var.environment}-application"
      error_message = "Select the TFC workspace dynatrace-<environment>-application matching var.environment."
    }
    precondition {
      condition     = alltrue([for id in setunion(local.all_account_ids, local.non_prod_account_ids) : can(regex("^[0-9]{12}$", id))])
      error_message = "SSM account lists must contain only comma-separated 12-digit account IDs."
    }
    precondition {
      condition     = length(setintersection(local.dev_account_ids, local.tst_account_ids)) == 0
      error_message = "An account cannot belong to both dev and tst. Fix the SSM parameters before applying."
    }
    precondition {
      condition     = length(setsubtract(local.non_prod_account_ids, local.all_account_ids)) == 0
      error_message = "Every dev/tst account must also appear in the all-accounts SSM parameter."
    }
    precondition {
      condition     = length(setsubtract(var.ready_account_ids, local.accounts_map[var.environment].accounts)) == 0
      error_message = "ready_account_ids must contain only accounts assigned to this workspace environment."
    }
  }
}

module "aws_connections" {
  source   = "../../modules/dynatrace-aws-cloud-v2"
  for_each = local.accounts_map[var.environment].accounts

  providers = { dynatrace = dynatrace }

  account_id        = each.key
  role_name         = var.role_name
  role_path         = var.role_path
  deployment_region = var.aws_region
  monitored_regions = local.monitored_regions
  enable_monitoring = contains(var.ready_account_ids, each.key)

  depends_on = [terraform_data.account_routing, dynatrace_hub_extension_active_version.aws]
}
