# Non-secret account configuration, automatically loaded by Terraform Cloud.
# Keep token values in AWS Secrets Manager, never in this file.
aws_region = "eu-west-2"

# Replace null with the object below once the endpoint and secret exist.
# cloudwatch_logs = null

cloudwatch_logs = {
  endpoint_url = "https://jew15896.live.dynatrace.com/api/v2/logs/ingest/aws_firehose"
  secret_arn   = "arn:aws:secretsmanager:eu-west-2:899045892145:secret:firehose-dynatrace-apikey-yzRScc"

  # Set this only if the secret uses a customer-managed KMS key:
  # secret_kms_key_arn = "arn:aws:kms:eu-west-2:899045892145:key/<key-id>"
}
