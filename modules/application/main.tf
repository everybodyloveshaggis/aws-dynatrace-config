resource "dynatrace_aws_connection" "this" {
  name = var.account_name

  role_based_auth {
    consumers = ["SVC:com.dynatrace.da"]
  }
}

resource "dynatrace_aws_connection_role_arn" "this" {
  aws_connection_id = dynatrace_aws_connection.this.id
  role_arn          = var.role_arn

  timeouts {
    create = "2m"
  }
}
