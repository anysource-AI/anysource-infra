# Deployment Telemetry
# 
# Automatically captures deployment completion status in Sentry after terraform apply
# This ensures we never forget to track deployments for observability and debugging
#
# The script:
# - Auto-detects infra_version from terraform.tfvars in the calling module
# - Sends deployment completion event to Sentry with metadata
# - Only runs after all infrastructure resources are successfully created
# - Requires SENTRY_DSN environment variable or sentry_dsn variable to be set
#
# See docs/deployment-guide.md for more information

locals {
  # Use customer_id if provided, otherwise fall back to domain_name
  effective_customer_id = var.customer_id != "" ? var.customer_id : var.domain_name

  # Determine which Sentry DSN to use: override variable takes precedence, then vault value
  # This matches the pattern used throughout the module for sentry_dsn
  effective_sentry_dsn = var.sentry_dsn != "" ? var.sentry_dsn : local.sentry_dsn

  # Default infra_version to backend_image_tag if not explicitly provided
  # This matches the comment in variables.tf about defaulting to app image tag
  effective_infra_version = var.infra_version != "" ? var.infra_version : local.backend_image_tag

  # Determine if we should run telemetry (requires sentry_dsn to be set from either source)
  should_run_telemetry = local.effective_sentry_dsn != ""
}

resource "null_resource" "deployment_telemetry" {
  # Only create this resource if telemetry is configured
  count = local.should_run_telemetry ? 1 : 0

  # Trigger on every apply to ensure we capture all deployments
  # Using timestamp() ensures telemetry runs on every terraform apply,
  # providing a complete audit trail of all deployment attempts
  # NOTE: This does NOT run on terraform plan - only on terraform apply
  triggers = {
    timestamp = timestamp()
  }

  # Send deployment completion event to Sentry
  # This provisioner ONLY executes during terraform apply (not plan)
  provisioner "local-exec" {
    # Use effective_customer_id for telemetry
    # The script will auto-detect infra_version from terraform.tfvars in the calling directory
    command = <<-EOT
      bash ${path.module}/../scripts/capture-deployment-completion.sh ecs ${local.effective_customer_id} success || \
      echo 'Warning: Failed to send deployment telemetry (non-fatal)'
    EOT

    # Pass through SENTRY_DSN and ENVIRONMENT to the script
    # Uses the effective DSN (override or vault value)
    # Uses effective_infra_version which defaults to backend_image_tag if not explicitly set
    # NOTE: AUTH_API_KEY is NOT needed here because SENTRY_DSN is already resolved
    environment = {
      SENTRY_DSN    = local.effective_sentry_dsn
      SENTRY_ORG    = "anysource-er"
      ENVIRONMENT   = var.environment
      INFRA_VERSION = local.effective_infra_version
    }

    # Working directory should be the calling module's directory
    # This allows the script to find terraform.tfvars for auto-detection
    working_dir = path.root
  }
}

# Output to confirm telemetry status
output "deployment_telemetry_enabled" {
  description = "Whether deployment telemetry is enabled (requires sentry_dsn)"
  value       = local.should_run_telemetry
}

output "deployment_telemetry_infra_version" {
  description = "The infrastructure version that will be reported in telemetry"
  value       = local.should_run_telemetry ? local.effective_infra_version : "telemetry disabled"
}
