locals {
  aws_extension_name = "com.dynatrace.extension.da-aws"
  monitored_regions  = sort(tolist(setunion(var.monitored_regions, ["us-east-1"])))
}