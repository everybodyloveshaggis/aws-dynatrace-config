## AWS account monitoring

This configuration creates a Clouds AWS monitoring connection, an IAM role, and a topology and metrics monitoring configuration for the AWS account mapped to the Terraform Cloud workspace. It uses the official `hashicorp/aws` and `dynatrace-oss/dynatrace` providers. The account ID is detected using `aws_caller_identity`; onboarding does not require AWS Organizations access.

### Authentication and monitoring

The module follows [Dynatrace's AWS monitoring onboarding guide](https://docs.dynatrace.com/docs/ingest-from/amazon-web-services/create-an-aws-connection/aws-connection-api):

- `dynatrace_aws_connection` uses `role_based_auth` with consumer `SVC:com.dynatrace.da`.
- The IAM role trusts `arn:aws:iam::314146291599:root` for `sts:AssumeRole`, restricted by an external ID equal to the connection ID.
- `dynatrace_aws_connection_role_arn` links the role after its policy attachment completes and retries for up to five minutes for IAM propagation.
- `dynatrace_hub_extension_v2_config` enables the AWS extension's essential topology and metrics feature sets after the connection is ready. It reads the installed extension version instead of hardcoding one.

The module retains the AWS managed `ReadOnlyAccess` policy. This is broad; review it against your organization's policy standards. GovCloud and China partitions are not supported. Logs and events ingestion are not configured.

This integration does not use the workflow consumer `APP:dynatrace.aws.connector` or its OIDC provider. `dynatrace_aws_credentials` is a separate, classic AWS monitoring integration.

### Prerequisites

Install the `com.dynatrace.extension.da-aws` extension in the Dynatrace environment before planning. For a first connection, open **Settings > Collect and capture > Cloud and virtualization > AWS** and leave it open for about ten minutes, as described in the onboarding guide. The active-version data source requires an installed extension.

The default AWS provider reads a JSON secret from Secrets Manager. The configured AWS credentials need `secretsmanager:GetSecretValue` on that secret and permissions to manage the IAM role and policy attachment. The secret must contain:

- `DYNATRACE_ENV_URL`: the platform environment URL, such as `https://abc12345.apps.dynatrace.com`.
- `DYNATRACE_PLATFORM_TOKEN`: a platform token whose service user can manage the AWS connection and extension configuration.

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

By default, monitoring covers `aws_region` (`eu-west-2`) and `us-east-1`. The latter is always included for global AWS resources. Override the monitored regions in workspace variables or `terraform.tfvars`:

```hcl
aws_role_name     = "DynatraceAwsMonitoringRole"
aws_region        = "eu-west-2"
monitored_regions = ["eu-west-2", "eu-west-1"]
```

Both topology and metrics use the same region list. The connection name is `aws-<account-id>`. Outputs expose the AWS account ID, role ARN, Dynatrace connection ID, and monitoring configuration ID.

Authenticate to Terraform Cloud and provide the workspace with the target account's AWS credentials, then run:

```text
terraform init
terraform plan
terraform apply
```

`aws_profile` is optional for local execution; leave it null when Terraform Cloud supplies AWS credentials. To onboard another account, change the workspace selected in `providers.tf` and configure that workspace with the other account's credentials and an accessible Dynatrace secret.

### Migrating the failed OIDC configuration

Run a full plan using the existing workspace and state. Switching authentication types replaces the Dynatrace connection, so its ID changes. Terraform updates the existing IAM role's trust policy with the new external ID, links the role, and creates the monitoring configuration. Any external references to the old connection ID must be updated.

The obsolete `aws_iam_openid_connect_provider.dynatrace` is removed from this configuration and will be destroyed if it is in the workspace state. If other workflow roles use that provider, transfer its management to their Terraform configuration before applying this migration.

The migration requires permission to delete the old IAM OIDC provider. Review the replacement and deletion in the plan. Increasing the old timeout or adding policy dependencies cannot repair the previous OIDC audience mismatch.

### Local checks

```text
terraform fmt -check -recursive
terraform validate
terraform -chdir=modules/aws-account init -backend=false
terraform -chdir=modules/aws-account test
```

Tests require Terraform 1.7 or later and use mocked AWS and Dynatrace providers; they do not provision infrastructure. They check the monitoring authentication, external-ID restriction, account binding, region handling, and account guard. A successful live apply is still required to verify tenant permissions and connectivity.
