

# The AWS extension must already be installed in the Dynatrace environment.
data "dynatrace_hub_extension_v2_active_version" "aws" {
  name = local.aws_extension_name
}

resource "dynatrace_hub_extension_v2_config" "aws" {
  name  = local.aws_extension_name
  scope = "integration-aws"
  value = jsonencode({
    # Match defaults returned by Dynatrace to avoid recurring plan differences.
    activationContext = "DATA_ACQUISITION"
    enabled           = true
    description       = var.account_name
    version           = data.dynatrace_hub_extension_v2_active_version.aws.active_version
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
        description  = var.account_name
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

  depends_on = [dynatrace_aws_connection_role_arn.this]
}
