## AWS account connections

This configuration creates one Dynatrace AWS connection and its AWS IAM role in the AWS account mapped to the Terraform Cloud workspace. It uses the official `hashicorp/aws` and `dynatrace-oss/dynatrace` providers and does not require AWS Organizations access. To onboard another account, use another Terraform Cloud workspace with that account's AWS credentials.

### Clouds v2 versus classic AWS monitoring

The linked AWS onboarding documentation is the newer Clouds AWS connection model. For that model, use `dynatrace_aws_connection` together with `dynatrace_aws_connection_role_arn`, as implemented in `modules/aws-account/main.tf`.

Do not replace those resources with `dynatrace_aws_credentials` for Clouds v2. `dynatrace_aws_credentials` manages the classic AWS credentials API and is a separate integration path. It will not create a native Clouds v2 connection managed by the Clouds app.

The default AWS provider reads the JSON secret from Secrets Manager. It requires `secretsmanager:GetSecretValue` for the configured ARN. The secret must contain `DYNATRACE_ENV_URL` and `DYNATRACE_PLATFORM_TOKEN`; `DYNATRACE_HTTP_OAUTH_PREFERENCE` is not required when the provider is explicitly configured with `platform_token`.

The AWS credentials mapped to the workspace must be an administrator, or have permission to read the secret, create the OIDC provider, IAM role, policy attachment, and related IAM resources in that account. The Dynatrace platform token must have `settings.read` and `settings.write` scopes.

The connection name is generated as `aws-<account-id>`. The AWS Console account name shown in the billing or account menu is not exposed by the standard account-level AWS APIs, and an IAM account alias is optional, so this configuration does not depend on either value.

### Configure accounts

Create a `terraform.tfvars` file based on this example:

```hcl
aws_role_name = "DynatraceAwsMonitoringRole"
```

Run Terraform with credentials that can access both profiles:

```text
terraform init
terraform plan
terraform apply
```

For another AWS account, create or reuse a Terraform Cloud workspace with AWS credentials for that account and use the same configuration. The account ID is detected automatically with `aws_caller_identity`; no Organization-level access or account ID variable is required.

The module attaches AWS managed `ReadOnlyAccess` because Dynatrace's AWS polling surface covers many AWS services. Review that choice against your organization's IAM policy standards before production use. GovCloud and China partitions are not supported by this Dynatrace connection model.
