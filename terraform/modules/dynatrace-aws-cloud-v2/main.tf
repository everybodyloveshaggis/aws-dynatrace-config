# Bootstrap creates the complete objectId before the independent IAM apply.
resource "dynatrace_aws_connection" "this" {
  name = local.account_name

  role_based_auth {
    consumers = ["SVC:com.dynatrace.da"]
  }
}

resource "dynatrace_aws_connection_role_arn" "this" {
  count = var.enable_monitoring ? 1 : 0

  aws_connection_id = dynatrace_aws_connection.this.id
  role_arn          = local.role_arn

  # The provider retries the initial association while IAM propagates.
  # Once associated, Dynatrace does not support changing this role ARN.
  timeouts {
    create = "2m"
  }
}
