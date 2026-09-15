## AWS account connections

This configuration creates one Dynatrace AWS connection and its AWS IAM role per account. It uses the official `hashicorp/aws` and `dynatrace-oss/dynatrace` providers and does not require AWS Organizations access.

### Clouds v2 versus classic AWS monitoring

The linked AWS onboarding documentation is the newer Clouds AWS connection model. For that model, use `dynatrace_aws_connection` together with `dynatrace_aws_connection_role_arn`, as implemented in `modules/aws-account/main.tf`.

Do not replace those resources with `dynatrace_aws_credentials` for Clouds v2. `dynatrace_aws_credentials` manages the classic AWS credentials API and is a separate integration path. It will not create a native Clouds v2 connection managed by the Clouds app.

The AWS credentials used by each provider alias must be an administrator, or have permission to create the OIDC provider, IAM role, policy attachment, and related IAM resources in that account. The Dynatrace token must have `settings.read` and `settings.write` scopes. Set `DYNATRACE_HTTP_OAUTH_PREFERENCE=true` when using a platform token.

### Configure accounts

Create a `terraform.tfvars` file based on this example:

```hcl
dt_platform_token        = "..."
dynatrace_environment_url = "https://abc.live.dynatrace.com"

aws_account_a_name    = "production"
aws_account_a_id      = "123456789012"
aws_account_a_profile = "aws-production"

aws_account_b_enabled = true
aws_account_b_name    = "staging"
aws_account_b_id      = "210987654321"
aws_account_b_profile = "aws-staging"
```

Run Terraform with credentials that can access both profiles:

```text
terraform init
terraform plan
terraform apply
```

Terraform provider aliases are static, so a new account requires another aliased `aws` provider and module block in `providers.tf` and `main.tf`. This is a Terraform limitation, not an AWS Organizations requirement. For more than two accounts, the same module can be called from separate root modules or workspaces, one per account.

The module attaches AWS managed `ReadOnlyAccess` because Dynatrace's AWS polling surface covers many AWS services. Review that choice against your organization's IAM policy standards before production use. GovCloud and China partitions are not supported by this Dynatrace connection model.
