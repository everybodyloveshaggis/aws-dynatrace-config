# Tenant-scoped: install once here, never once per AWS account.
# With null, the extension must already be installed in this Dynatrace tenant.
resource "dynatrace_hub_extension_active_version" "aws" {
  provider = dynatrace.extension_installation
  count    = var.aws_extension_version == null ? 0 : 1

  name    = "com.dynatrace.extension.da-aws"
  version = var.aws_extension_version
}
