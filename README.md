## AWS account monitoring

This configuration creates a Clouds AWS monitoring connection, an IAM role, and a topology and metrics monitoring configuration for the AWS account mapped to the Terraform Cloud workspace. It can optionally stream all CloudWatch log groups in the configured AWS region to Dynatrace through Amazon Data Firehose. It uses the official `hashicorp/aws` and `dynatrace-oss/dynatrace` providers. The account ID is detected using `aws_caller_identity`; onboarding does not require AWS Organizations access.

- `modules/application` contains only Dynatrace provider resources: the connection, role association, and monitoring settings.
- `modules/infrastructure` contains only AWS provider resources: the monitoring IAM role and optional Firehose, subscription, IAM, S3 backup, and delivery diagnostics.
- The root configures providers and credentials and connects the modules. The connection ID becomes the AWS role's external ID; the role ARN returns to the application after its policy is attached. Avoid module-wide `depends_on` between these modules, which would create a dependency cycle.

### Authentication and monitoring

The module follows [Dynatrace's AWS monitoring onboarding guide](https://docs.dynatrace.com/docs/ingest-from/amazon-web-services/create-an-aws-connection/aws-connection-api):

- `dynatrace_aws_connection` uses `role_based_auth` with consumer `SVC:com.dynatrace.da`.
- The IAM role trusts `arn:aws:iam::314146291599:root` for `sts:AssumeRole`, restricted by an external ID equal to the connection ID.
- `dynatrace_aws_connection_role_arn` links the role after its policy attachment completes and retries for up to two minutes for IAM propagation.
- `dynatrace_hub_extension_v2_config` enables the AWS extension's essential topology and metrics feature sets after the connection is ready. It reads the installed extension version instead of hardcoding one.

The infrastructure module retains the AWS managed `ReadOnlyAccess` policy. This is broad; review it against your organization's policy standards. GovCloud and China partitions are not supported. Log forwarding is disabled by default; events ingestion is not configured.

This integration does not use the workflow consumer `APP:dynatrace.aws.connector` or its OIDC provider. `dynatrace_aws_credentials` is a separate, classic AWS monitoring integration.

### Prerequisites

Install the `com.dynatrace.extension.da-aws` extension in the Dynatrace environment before planning. For a first connection, open **Settings > Collect and capture > Cloud and virtualization > AWS** and leave it open for about ten minutes, as described in the onboarding guide. The active-version data source requires an installed extension.

Use Terraform 1.10 or later, including the Terraform version selected for the Terraform Cloud workspace. The AWS provider remains on the locked 5.100.0 release, which supports ephemeral Secrets Manager reads.

AWS authentication continues to use the existing Terraform Cloud dynamic credentials configuration (`TFC_AWS_PROVIDER_AUTH=true` and `TFC_AWS_RUN_ROLE_ARN=arn:aws:iam::899045892145:role/terraform-role`). The default and secret-reading AWS providers use the same runner identity. No AWS access keys or session tokens are read into Terraform state or supplied in tfvars.

An aliased AWS provider reads the Dynatrace JSON secret in the region from its ARN. The run role needs `secretsmanager:GetSecretValue` on that secret (and `kms:Decrypt` if it uses a customer-managed KMS key), plus permissions to manage the IAM role and policy attachment. The secret must contain:

- `DYNATRACE_ENV_URL`: the platform environment URL, such as `https://abc12345.apps.dynatrace.com`.
- `DYNATRACE_PLATFORM_TOKEN`: a platform token whose service user can manage the AWS connection and extension configuration.

The read uses an [`ephemeral` resource](https://developer.hashicorp.com/terraform/language/block/ephemeral), so the secret response and derived provider credentials are omitted from state and saved plans. Invalid JSON, missing/empty token values, and invalid environment URLs stop the run with a configuration error. The environment URL must be an HTTPS origin without a path (an optional trailing slash is allowed).

The platform token needs these scopes, with matching permissions assigned to its service user:

```text
settings:objects:read
settings:objects:write
extensions:definitions:read
extensions:configurations:read
extensions:configurations:write
```

The settings permissions must cover `builtin:hyperscaler-authentication.connections.aws`; the extension permissions must cover `com.dynatrace.extension.da-aws`. `settings.read` and `settings.write` are classic API-token scopes, not the platform-token scopes used here. The provider is configured explicitly with `platform_token`.

### Configuration

Set the secret ARN in the checked-in `secrets.auto.tfvars` file. It contains only the reference, never credentials:

```hcl
dynatrace_secret_arn = "arn:aws:secretsmanager:eu-west-2:899045892145:secret:dynatrace-secrets-sPjhXs"
```

Terraform Cloud automatically loads this file with the configuration; no new workspace variable is needed. The `.gitignore` exceptions permit this ARN-only file and the non-secret `account.auto.tfvars` file while continuing to ignore other tfvars files. Reserve Terraform Cloud workspace variables for TFC-to-AWS role authentication only. Keep all other configuration in the checked-in tfvars files. Remove any existing non-authentication workspace variables after transferring their values to these files, because workspace variables take precedence.

By default, monitoring covers `aws_region` (`eu-west-2`) and `us-east-1`. The latter is always included for global AWS resources. Configure the region and any monitoring overrides in `account.auto.tfvars`:

```hcl
aws_role_name     = "DynatraceAwsMonitoringRole"
aws_region        = "eu-west-2"
monitored_regions = ["eu-west-2", "eu-west-1"]
```

Both topology and metrics use the same region list. The connection name is `aws-<account-id>`. Outputs expose the AWS account ID, role ARN, Dynatrace connection ID, and monitoring configuration ID.

### Optional CloudWatch log forwarding

Leave `cloudwatch_logs` unset (or set it to `null`) for accounts without Firehose. Enable it per account with the following Terraform variable. The values below are examples; use your environment's actual ingest endpoint and secret ARN:

```hcl
cloudwatch_logs = {
  endpoint_url = "https://abc12345.live.dynatrace.com/api/v2/logs/ingest/aws_firehose"
  secret_arn   = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:dynatrace-log-ingest-AbCdEf"

  # Optional defaults:
  # name                  = "dynatrace-cloudwatch-logs"
  # backup_retention_days = 30
  # secret_kms_key_arn     = "arn:aws:kms:eu-west-2:123456789012:key/..."
}
```

Set this non-secret configuration in the checked-in `account.auto.tfvars` file, which Terraform Cloud loads automatically. Replace its `cloudwatch_logs = null` assignment with the object above using your actual endpoint and secret ARN; a commented template is included in the file. The `.gitignore` already permits this specific file. Log forwarding remains disabled until those values are supplied. Do not create a Terraform Cloud workspace variable for this configuration. No token value belongs in tfvars.

The referenced secret must already exist in the forwarding account and `aws_region`. Its JSON must contain `{"api_key":"<Dynatrace API token with logs.ingest permission>"}`. This is a log ingestion credential, separate from the platform token used to manage Dynatrace settings. Firehose reads the secret itself at runtime; Terraform only stores its ARN, never fetches its value, and does not populate Firehose's state-backed `access_key` argument. If the secret uses a customer-managed KMS key, supply `secret_kms_key_arn` and ensure that key's policy permits the delivery role to decrypt it. Back up or securely restore the ingestion secret as part of disaster recovery.

Use the full Firehose ingestion endpoint, normally on `live.dynatrace.com`, rather than the `apps.dynatrace.com` URL used by the Dynatrace provider. See [Dynatrace's Firehose setup](https://docs.dynatrace.com/docs/ingest-from/amazon-web-services/integrate-with-aws/aws-logs-ingest/lma-stream-logs-with-firehose) and [AWS's required secret format](https://docs.aws.amazon.com/firehose/latest/dev/secrets-manager-whats-secret.html).

Enabling this option creates:

- A Firehose stream delivering directly to Dynatrace with GZIP HTTP requests, a 1 MiB / 60 second buffer, and 900 seconds of delivery retries. The CloudWatch envelope remains intact for Dynatrace to decode.
- An encrypted, private S3 bucket for failed deliveries, expiring them after 30 days by default.
- IAM roles restricted to this account's CloudWatch Logs, the delivery stream, backup bucket, and ingestion secret.
- An account-level subscription with an empty event filter. It includes all existing and future subscription-capable CloudWatch log groups in `aws_region`, including CloudTrail and VPC flow logs. The stream's own diagnostic log group is the sole exclusion, preventing recursive delivery.
- The Dynatrace extension's `cloudWatchLogsConfiguration`, enabled for `aws_region` only after the subscription is ready. Deployment remains `MANUAL`; Terraform manages the resources directly without CloudFormation stacks.

Log forwarding is regional. `monitored_regions` controls topology and metrics only; adding regions there does not deploy additional Firehose streams. CloudWatch subscriptions support the Standard log class and forward new events, not historical log contents. An account can have only one account-level subscription policy per region; an existing one must be reconciled or imported before applying this configuration. Existing log-group subscriptions are additive and can cause duplicate delivery if they already forward to Dynatrace. See [AWS subscription documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Subscriptions.html) and [recursion prevention](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Subscriptions-recursion-prevention.html).

The Terraform run role needs permissions to manage Firehose, the backup S3 bucket and its configuration, CloudWatch log groups/streams/account policies, and the new IAM roles/inline policies, including `iam:PassRole`. The Firehose delivery role receives `secretsmanager:GetSecretValue` on the ingestion secret. The runner does not need to read that ingestion token.

Terraform waits 60 seconds after creating or changing the CloudWatch delivery role's permissions before configuring the account-level subscription. This mitigates IAM propagation errors during CloudWatch's Firehose test delivery. Unchanged applies do not repeat the wait. AWS propagation can occasionally take longer, so a delayed retry may still be necessary.

Outputs `cloudwatch_logs_firehose_arn` and `cloudwatch_logs_backup_bucket` identify the stream and failed-delivery bucket; both are null when disabled. After applying, produce a new log event in a Standard log group, check Firehose's delivery metrics and diagnostic log stream, and confirm the event appears in Dynatrace. Creating a new group should require no further Terraform run.

Setting `cloudwatch_logs = null` removes the forwarding resources and disables the Dynatrace log setting. The backup bucket deliberately has `force_destroy = false`: if failed deliveries exist, recover or explicitly dispose of them before removing the bucket. Do not treat this bucket as a permanent log archive; it contains failures only and has the configured retention period.

### Migrating the module split

Keep the existing workspace and state and run a normal plan. `moved.tf` maps all five existing managed resources from `module.aws_account` to `module.application` or `module.infrastructure`, preserving their remote identities. With log forwarding disabled, the split should not replace the monitoring IAM role or Dynatrace connection. Keep these move declarations until every account's state has migrated. The application module now takes `role_arn`; standalone consumers must create the AWS infrastructure separately.

### Deploying

Authenticate to Terraform Cloud, retain the workspace's AWS dynamic credentials setup, and run:

```text
terraform init
terraform plan
terraform apply
```

`aws_profile` is optional for local execution; leave it null when Terraform Cloud supplies AWS credentials. To onboard another account, change the workspace selected in `providers.tf`, configure that workspace's AWS run role, and update `secrets.auto.tfvars` to an accessible Dynatrace secret.

### Migrating the secret read

Run a normal plan and apply after this change. Terraform removes the old `data.aws_secretsmanager_secret_version.dynatrace` entry from the current state; the actual Secrets Manager secret is unchanged. The migration plan can still include the old value from its prior state. After the successful apply removes that entry, subsequent plans and state snapshots do not persist the fetched secret value.

Earlier state versions and saved plans can still contain the old token. This code change does not erase Terraform Cloud history. Rotate the Dynatrace token after migrating if you need those historical copies to stop granting access, and handle old state/plan retention according to your requirements. AWS dynamic credentials already remain outside state and need no migration.

### Migrating the failed OIDC configuration

Run a full plan using the existing workspace and state. Switching authentication types replaces the Dynatrace connection, so its ID changes. Terraform updates the existing IAM role's trust policy with the new external ID, links the role, and creates the monitoring configuration. Any external references to the old connection ID must be updated.

The obsolete `aws_iam_openid_connect_provider.dynatrace` is removed from this configuration and will be destroyed if it is in the workspace state. If other workflow roles use that provider, transfer its management to their Terraform configuration before applying this migration.

The migration requires permission to delete the old IAM OIDC provider. Review the replacement and deletion in the plan. Increasing the old timeout or adding policy dependencies cannot repair the previous OIDC audience mismatch.

### Local checks

```text
terraform fmt -check -recursive
terraform validate
terraform -chdir=modules/application init -backend=false
terraform -chdir=modules/application test
terraform -chdir=modules/infrastructure init -backend=false
terraform -chdir=modules/infrastructure test
```

Use the same Terraform 1.10+ version as the root configuration. Tests use mocked AWS and Dynatrace providers; they do not provision infrastructure. They check monitoring authentication, external-ID restrictions, account binding, region handling, the account guard, optional log resources, account-wide subscription coverage, recursion prevention, runtime secret references, and Dynatrace log settings. A successful live apply is still required to verify tenant permissions and connectivity.

For secret handling, run `python3 -m unittest discover -s tests -p 'test_*.py' -v` with Terraform 1.10+ and Python 3 installed. These tests use the locked AWS provider against a local HTTP stub with synthetic credentials. They check malformed-secret rejection and verify that fetched credentials reach provider configuration but do not appear in state or saved plan contents. They use an isolated local backend and do not contact AWS, Dynatrace, or Terraform Cloud.
