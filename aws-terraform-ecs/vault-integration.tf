# WorkOS Vault Integration for Sentry Relay Credentials
#
# This file automatically fetches Sentry Relay credentials from WorkOS Vault
# during terraform plan/apply. No manual script execution required.
#
# Graceful Degradation:
# If credentials are not available in WorkOS Vault, the script returns empty values
# and deployment continues WITHOUT Sentry Relay. This allows deployments to proceed
# even when Sentry is not yet provisioned for the customer.
#
# Prerequisites (optional):
# 1. Anysource team has populated the customer's WorkOS Vault with:
#    Name: anysource-sentry-relay-credentials
#    Value: {"public_key": "...", "secret_key": "...", "id": "...", "sentry_dsn": "..."}
# 2. Customer has set auth_api_key in terraform.tfvars (same WorkOS API key)
#
# The external data source calls scripts/vault-fetch-relay.sh which:
# 1. Lists secrets in WorkOS Vault
# 2. Finds 'anysource-sentry-relay-credentials' by name
# 3. Retrieves and parses the JSON value
# 4. Returns credentials to Terraform (or empty values if not found)

data "external" "relay_credentials" {
  program = ["bash", "${path.module}/../../scripts/vault-fetch-relay.sh"]

  query = {
    api_key = var.auth_api_key # Reuse existing WorkOS API key
  }
}

# Make credentials available as local values for use in other resources
# These will be empty strings if credentials are not available in WorkOS Vault
locals {
  relay_public_key = data.external.relay_credentials.result.public_key
  relay_secret_key = data.external.relay_credentials.result.secret_key
  relay_id         = data.external.relay_credentials.result.relay_id
  sentry_dsn       = data.external.relay_credentials.result.sentry_dsn

  # Flag to determine if Sentry Relay should be deployed
  # Relay is deployed only if:
  # 1. var.sentry_relay_enabled is true (explicit override)
  # 2. AND valid credentials are available in WorkOS Vault
  # This allows explicit disabling even when credentials exist (for debugging/cost control)
  deploy_relay = var.sentry_relay_enabled && local.relay_public_key != "" && local.relay_secret_key != "" && local.relay_id != ""
}
