locals {
  # Account IDs are public identifiers. insecure_value permits stable for_each keys.
  all_account_ids = toset(compact([for id in split(",", data.aws_ssm_parameter.account_ids.insecure_value) : trimspace(id)]))
  dev_account_ids = toset(compact([for id in split(",", data.aws_ssm_parameter.dev_accounts.insecure_value) : trimspace(id)]))
  tst_account_ids = toset(compact([for id in split(",", data.aws_ssm_parameter.tst_accounts.insecure_value) : trimspace(id)]))

  non_prod_account_ids   = setunion(local.dev_account_ids, local.tst_account_ids)
  filtered_prod_accounts = setsubtract(local.all_account_ids, local.non_prod_account_ids)
  accounts_map = {
    dev = { accounts = local.dev_account_ids }
    tst = { accounts = local.tst_account_ids }
    prd = { accounts = local.filtered_prod_accounts }
  }

  monitored_regions         = var.monitored_regions == null ? toset([var.aws_region]) : var.monitored_regions
  dynatrace_secret          = try(jsondecode(ephemeral.aws_secretsmanager_secret_version.dynatrace.secret_string), {})
  dynatrace_environment_url = try(local.dynatrace_secret.DYNATRACE_ENV_URL, null)
  dynatrace_platform_token  = try(local.dynatrace_secret.DYNATRACE_PLATFORM_TOKEN, null)
}
