# Migrating existing state

This rewrite changes both resource addresses and state ownership. Do not apply it unchanged to the previous single-account workspace: Terraform would otherwise plan to destroy resources at the old addresses. The examples below use account `111111111111`; substitute the real account, tenant, objectId and configuration ID from the existing state. Keep a restricted backup of that state and pause automated applies in the affected workspaces during the handoff.

The application component now includes `migrations.tf` for the observed existing production account `899045892145`, and `env/prd.tfvars` keeps that already-active account in `ready_account_ids`. Its three Dynatrace objects move to the new addresses. The old infrastructure module is released without destruction. Do not add duplicate declarations from the illustrative example below. These account-specific moves do not migrate a different account's legacy state; adapt them before onboarding another legacy workspace.

## 1. Choose the destination application workspace

If the existing state is already in the correct tenant's `dynatrace-dev-application`, `dynatrace-tst-application` or `dynatrace-prd-application` workspace, use the same-state moves below. Renaming the old TFC workspace to its intended environment can also preserve its state; configure its working directory to `terraform/components/application` and its matching `environment` input.

Add this temporary `migration.tf` to the application component when retaining that state:

```hcl
moved {
  from = module.application.dynatrace_aws_connection.this
  to   = module.aws_connections["111111111111"].dynatrace_aws_connection.this
}
moved {
  from = module.application.dynatrace_aws_connection_role_arn.this
  to   = module.aws_connections["111111111111"].dynatrace_aws_connection_role_arn.this[0]
}
moved {
  from = module.application.dynatrace_hub_extension_v2_config.aws
  to   = module.aws_connections["111111111111"].dynatrace_hub_extension_v2_config.aws[0]
}

# Transfer ownership without deleting the role or its attachments.
removed {
  from = module.infrastructure
  lifecycle {
    destroy = false
  }
}
```

Set `ready_account_ids` to include this already-working account **before** planning the moves. Preserve the existing role name/path and use credentials for the same Dynatrace tenant. The full inventory and classification parameters must place it in this workspace's environment. Confirm the plan moves all three Dynatrace objects, forgets the IAM resources without destroying them, and leaves the connection ID unchanged. New accounts can remain unready.

For older states still using `module.aws_account`, change each Dynatrace `from` address to that module and replace the module-wide `removed` block with individual `removed` blocks for its `aws_iam_role.dynatrace` and `aws_iam_role_policy_attachment.read_only` resources, each with `destroy = false`. Inspect the actual state for any other AWS objects requiring transfer. A module-wide removal of `module.aws_account` cannot coexist with moves of children out of that same module.

If the destination workspace has a different state, `moved` blocks cannot cross the boundary. In the old configuration, remove the corresponding resource declarations and use `removed` blocks with `destroy = false`, then apply to release ownership. In the new component, use Terraform `import` blocks for the existing connection and monitoring configuration at their new addresses, using the complete IDs from state. The monitoring ID is the provider composite `com.dynatrace.extension.da-aws#-#<configuration-objectId>`, not the bare API configuration UUID. Import the role association using the complete connection objectId, which is also its provider resource ID. Include the account in `ready_account_ids`. Review a no-replacement plan and apply before removing the import blocks. Never let two workspaces manage the same objects simultaneously.

Terraform `state list` and `state show` are read-only ways to obtain existing addresses/IDs; the handoff mutations above are declarative Terraform. Avoid committing state backups or output containing old credentials.

## 2. Adopt the IAM role in the separate repository

After the source state has released IAM ownership and the application has published `aws_connections`, configure the account's IAM workspace with its AWS credentials, `environment`, `clouds_organization`, and `TFE_TOKEN`. Its working directory is `terraform/module_calls_to_resources`.

Add this temporary file to that IAM root:

```hcl
import {
  to = module.dynatrace_aws_cloud_iam_role["this"].aws_iam_role.this
  id = "DynatraceAwsMonitoringRole"
}

# Adopt the existing broad attachment only for its controlled retirement.
resource "aws_iam_role_policy_attachment" "legacy_read_only" {
  role       = "DynatraceAwsMonitoringRole"
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

import {
  to = aws_iam_role_policy_attachment.legacy_read_only
  id = "DynatraceAwsMonitoringRole/arn:aws:iam::aws:policy/ReadOnlyAccess"
}
```

Substitute the actual role name, including in the attachment import ID. The first IAM plan must import the existing role and broad attachment, create/attach the two custom policies, and keep the external ID equal to the existing full connection objectId. Preserve any existing permissions boundary through `permissions_boundary`. Apply this plan first.

Then remove **both** import blocks and the temporary `legacy_read_only` resource. The next IAM plan must detach only `ReadOnlyAccess`; the role and both custom attachments remain. Apply it. This ordering ensures the required custom permissions are attached before retiring the broad policy. The permanent IAM module never attaches `ReadOnlyAccess`.

If custom policies already exist outside Terraform, import them and their attachments rather than trying to recreate them. Use the module's actual names and addresses; its managed policies are named `<role-name>-Monitoring` and `<role-name>-Monitoring-2`.

## 3. Finish and verify

Apply the application workspace again, confirm monitoring is healthy, and enable ordinary CI after plans show only intended changes. Keep same-state `moved` blocks until every affected state has migrated. Retain the appropriate `removed` declarations for the handoff until source states have released ownership.

The rewrite covers topology and metrics only. If optional Firehose/log-forwarding resources exist in the old infrastructure module, its `removed` block preserves them but leaves them unmanaged. Transfer those resources to another Terraform configuration before completing the handoff, or explicitly retire them in the old configuration first. Preserve failed-delivery bucket data as appropriate. The new monitoring configuration disables its log setting.

Old state versions may still contain credentials from earlier non-ephemeral secret reads; moving the configuration does not purge state history. No state migration, AWS apply or Dynatrace apply is performed by this repository rewrite itself.
