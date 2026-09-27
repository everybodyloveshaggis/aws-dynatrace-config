locals {
  account_name       = var.account_name == null ? "aws-${var.account_id}" : var.account_name
  aws_extension_name = "com.dynatrace.extension.da-aws"
  monitored_regions  = sort(tolist(setunion(var.monitored_regions, ["us-east-1"])))
  role_arn           = "arn:aws:iam::${var.account_id}:role${var.role_path}${var.role_name}"
}
