# The root component manages extension installation once per tenant.
# Bootstrap must not require that extension to be installed yet.
data "dynatrace_hub_extension_v2_active_version" "aws" {
  count = var.enable_monitoring ? 1 : 0

  name = local.aws_extension_name
}

resource "dynatrace_hub_extension_v2_config" "aws" {
  count = var.enable_monitoring ? 1 : 0

  name  = local.aws_extension_name
  scope = "integration-aws"
  value = jsonencode({
    activationContext = "DATA_ACQUISITION"
    enabled           = true
    description       = local.account_name
    version           = data.dynatrace_hub_extension_v2_active_version.aws[0].active_version
    featureSets = [
      "ApplicationELB_essential",
      "AutoScaling_essential",
      "CloudFront_essential",
      "DynamoDB_essential",
      "EBS_essential",
      "EC2_essential",
      "ECS_essential",
      "Firehose_essential",
      "Lambda_essential",
      "NetworkELB_essential",
      "RDS_essential",
      "Route53_essential",
      "S3_essential",
      "SQS_essential",
    ]
    aws = {
      namespaces       = []
      tagEnrichment    = []
      tagFiltering     = []
      deploymentRegion = var.deployment_region
      credentials = [{
        enabled      = true
        description  = local.account_name
        connectionId = dynatrace_aws_connection.this.id
        accountId    = var.account_id
      }]
      regionFiltering = local.monitored_regions
      metricsConfiguration = {
        enabled = true
        regions = local.monitored_regions
      }
      cloudWatchLogsConfiguration = {
        enabled = false
        regions = []
      }
      configurationMode         = "QUICK_START"
      deploymentScope           = "SINGLE_ACCOUNT"
      deploymentMode            = "MANUAL"
      manualDeploymentStatus    = "COMPLETE"
      automatedDeploymentStatus = "NA"
    }
  })

  lifecycle {
    precondition {
      condition     = contains(local.monitored_regions, var.deployment_region)
      error_message = "deployment_region must be us-east-1 or one of monitored_regions."
    }
  }

  depends_on = [dynatrace_aws_connection_role_arn.this]
}
