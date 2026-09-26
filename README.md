# AWS Clouds monitoring

Terraform manages a Dynatrace AWS connection and topology/metrics configuration for every account discovered through SSM. IAM lives in the separate **aws-dynatrace-iam** repository, with one workspace per AWS account. There is no AWS Organizations account discovery, CloudFormation, shell provisioner, log forwarding or events ingestion.

```text
aws-dynatrace-config/
  terraform/
    components/application/          # TFC working directory
    modules/dynatrace-aws-cloud-v2/   # One account's Dynatrace resources

aws-dynatrace-iam/                    # Separate sibling Git repository
  terraform/
    module_calls_to_resources/       # TFC working directory, one account per workspace
    modules/dynatrace-aws-cloud-iam-role/
```

## Workspaces and routing

All three application workspaces use `terraform/components/application` as their Terraform working directory. Include the repository's `terraform/modules` directory in the uploaded/VCS configuration. Use Terraform **1.10 or later** (CI uses 1.15.6).

Set **Settings → General → Terraform Working Directory** to exactly `terraform/components/application` in each HCP workspace and save it before the first remote plan. This is an HCP workspace setting: neither `TF_WORKSPACE`, the `cloud` block nor `-chdir` sets it. Workspaces created automatically by `terraform init` initially have an empty working directory.

With this setting, running from the application directory makes Terraform upload the repository root, including `terraform/modules`. If it is empty, only the application directory is uploaded and remote initialization fails with `lstat ../../modules: no such file or directory`. See [HashiCorp's parent-directory upload behavior](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings#parent-directory-uploads). The same setting is required for the CLI-based GitHub workflows.

| TFC workspace | Terraform variable `environment` | Accounts |
| --- | --- | --- |
| `dynatrace-dev-application` | `dev` | `/arecps/dynatrace/dev_accounts` |
| `dynatrace-tst-application` | `tst` | `/arecps/dynatrace/tst_accounts` |
| `dynatrace-prd-application` | `prd` | All accounts minus dev and tst |

`account_ids_ssm_path` identifies the complete inventory and defaults to `/arecps/accounts/all_account_ids`. All three parameters must exist in the runner's AWS account and `aws_region`, using SSM `String` or `StringList` values. Values are comma-separated 12-digit IDs. Whitespace, duplicate IDs and empty CSV entries are discarded. For an empty classification, a String containing a space can represent an empty list. Dev/tst overlaps, malformed IDs and non-production accounts missing from the full inventory fail the plan. Each workspace creates resources only for its own environment.

The application runner needs `ssm:GetParameter` on the three parameters and `secretsmanager:GetSecretValue` on its tenant secret (plus `kms:Decrypt` if required). It does not assume roles into monitored accounts or manage AWS resources. Keep TFC AWS dynamic credentials for the runner; configure a separate AWS run role in each IAM workspace.

## Tenant credentials and extension

Set inputs in `terraform/components/application/env/<environment>.tfvars`, following [env/prd.tfvars](terraform/components/application/env/prd.tfvars), or configure them as HCP workspace Terraform variables. Required inputs: `environment`, `dynatrace_environment_id`, `dynatrace_secret_arn`. Override `account_ids_ssm_path` if the default inventory path differs. Environment files contain configuration and secret ARNs only; token values stay in Secrets Manager.

The secret's JSON contains:

```json
{
  "DYNATRACE_ENV_URL": "https://abc12345.apps.dynatrace.com",
  "DYNATRACE_PLATFORM_TOKEN": "<platform-token>"
}
```

`dynatrace_environment_id` must match the URL's first hostname component. Secrets are read with an ephemeral AWS resource, keeping tokens out of state and saved plans. The secret is read in the region encoded by its ARN. No token values belong in tfvars.

The platform token and its service user need `settings:objects:read`, `settings:objects:write`, `extensions:definitions:read`, `extensions:configurations:read` and `extensions:configurations:write`, scoped to `builtin:hyperscaler-authentication.connections.aws` and `com.dynatrace.extension.da-aws` as described in the [Dynatrace guide](https://docs.dynatrace.com/docs/ingest-from/amazon-web-services/create-an-aws-connection/aws-connection-api).

If the AWS extension is installed, leave `aws_extension_version = null`. For Terraform-managed installation/activation, set an explicit available version and add `DYNATRACE_API_TOKEN` to the secret. The [native extension resource](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs/resources/hub_extension_active_version) requires classic token scopes `extensions.write`, `extensionEnvironment.write`, `extension.read` and `extensionEnvironment.read`. A separate provider alias uses this classic credential only for installation; connection management uses the platform token. The installer uses the provider's Extensions API implementation. Compatibility with the AWS extension and your tenant still needs a live apply; its version is deliberately not guessed. Monitoring reads the active version after installation.

## Deployment sequence

Onboarding takes three ordered applies across the two repositories. No targeted apply or manual Dynatrace API request is needed.

1. **Application bootstrap:** apply the matching application workspace with new accounts absent from `ready_account_ids`. Keep existing ready accounts in the set. Connections are created without a role ARN; `aws_connections` publishes their complete objectIds and expected role identities.
2. **Account IAM:** apply the IAM repo in each new account. It reads `tfe_outputs` from `dynatrace-<environment>-application`, selects its caller account ID, and uses `object_id` unchanged as `sts:ExternalId`. It creates the cross-account role and the two documented customer-managed policies.
3. **Application activation:** add successfully provisioned accounts to `ready_account_ids` and apply again. Terraform associates each role ARN before enabling topology and metrics. Connection IDs remain unchanged.

The bootstrap connection is incomplete until activation. The role ARN is calculated from the account ID, role path and role name, so there is no reverse state dependency. A TFC run trigger does not replace the readiness sequence or establish that IAM has applied successfully.

The IAM repo reads this **nonsensitive** output containing public identifiers:

```hcl
aws_connections = {
  "111111111111" = {
    object_id               = "<entire-settings-objectId>"
    environment             = "dev"
    dynatrace_environment_id = "abc12345"
    role_name               = "DynatraceAwsMonitoringRole"
    role_path               = "/"
    role_arn                = "arn:aws:iam::111111111111:role/DynatraceAwsMonitoringRole"
  }
}
```

The IAM workspace's TFE token needs output-read access to the corresponding application workspace. AWS dynamic credentials do not grant access to TFC outputs. The IAM README documents its `TFE_TOKEN` and Terraform variables.

## Existing deployments and lifecycle

**Read [MIGRATION.md](MIGRATION.md) before applying this rewrite to existing state.** Changing the working directory does not migrate resources between TFC workspaces. Old resource addresses and state ownership need explicit migration.

The provider cannot change the role ARN on an existing connection. Keep `role_name` and `role_path` stable after activation; changing them requires replacing the connection and updating IAM with the new objectId. Removing an account from `ready_account_ids` removes its monitoring configuration, but the provider's association deletion is a no-op and does not revoke AWS access. Revoke/remove the role in IAM when offboarding, then remove its connection from the application inventory.

Removing an account from SSM destroys its connection on the next apply. Moving an account between environments creates a new objectId in the destination tenant: coordinate removal from the old workspace, bootstrap in the new one, IAM using the new environment's output, then activation. Removing an account from dev/tst without removing it from the full inventory assigns it to production by design.

Monitoring includes `us-east-1` for global services and the configured regions. This supports commercial AWS accounts. The two Dynatrace-supplied policies replace AWS `ReadOnlyAccess`; they retain wildcard resources where specified by Dynatrace. `organizations:DescribeOrganization` is metadata access, not account enumeration.

## CLI and checks

The cloud block selects your TFC organization `smdevops96_org`. For CLI use, set `TF_WORKSPACE=dynatrace-dev-application` (or tst/prd), authenticate to TFC and run:

```sh
terraform -chdir=terraform/components/application init
terraform -chdir=terraform/components/application plan -var-file=env/dev.tfvars
terraform -chdir=terraform/components/application apply -var-file=env/dev.tfvars
```

Use the matching file for the selected workspace (`env/prd.tfvars` for production). If that environment uses HCP workspace variables instead, omit `-var-file`.

GitHub plan/apply workflows run all three workspaces. After checkout, each job selects `env/<matrix environment>.tfvars` and passes it through `-var-file` to both plan and apply if the file exists. With no matching file, the job uses its HCP workspace variables and `TF_VAR_environment`. Only `prd.tfvars` is currently supplied; add dev/tst files when their file-based configuration is ready. Git allows these three named files, so commit and push them along with the workflow changes for GitHub Actions to read them.

Configure repository secret `TF_API_TOKEN`. Keep the repository root as the upload context and configure the HCP working directory so sibling modules are included. The original push-to-main apply behavior is retained. Direct runs started by HCP VCS/UI do not execute these GitHub steps and do not automatically load files under `env`; those runs need workspace variables or their own explicit variable-file selection.

For the CLI-driven workflows here, explicit `-var-file` values override ordinary workspace Terraform variables; priority variable sets can still override them. See [HCP variable precedence](https://developer.hashicorp.com/terraform/cloud-docs/variables#precedence). Keep `environment` in each file consistent with its workspace; the existing routing guard rejects a mismatch.

Credential-free checks:

```sh
terraform fmt -check -recursive terraform
terraform -chdir=terraform/components/application init -backend=false
terraform -chdir=terraform/components/application validate
terraform -chdir=terraform/modules/dynatrace-aws-cloud-v2 init -backend=false
terraform -chdir=terraform/modules/dynatrace-aws-cloud-v2 test
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Tests use mocked Dynatrace resources and a local synthetic Secrets Manager service. They cover routing, invalid inventories, bootstrap/activation, role identity, monitoring regions and secret handling without provisioning infrastructure. Live permissions and connectivity require a real plan/apply.
