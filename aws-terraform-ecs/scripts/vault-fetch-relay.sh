#!/usr/bin/env bash
#
# Terraform external data source script for fetching Sentry Relay credentials from WorkOS Vault
#
# This script is called automatically by Terraform's external data source.
# It receives input via stdin as JSON and outputs credentials as JSON to stdout.
#
# Input (from Terraform):
#   {"api_key": "sk_live_..."}
#
# Output (to Terraform):
#   {"public_key": "...", "secret_key": "...", "relay_id": "...", "sentry_dsn": "..."}
#   OR empty values if credentials are not available (to allow graceful deployment without Sentry)
#
# DO NOT run this script manually - it's called by Terraform automatically.

set -euo pipefail

# Parse input from Terraform (reads JSON from stdin)
eval "$(jq -r '@sh "API_KEY=\(.api_key)"')"

# Validate API key was provided
if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
  echo "WARNING: WorkOS API key not provided - deploying without Sentry Relay" >&2
  # Return empty values to allow deployment without Sentry
  jq -n '{
    "public_key": "",
    "secret_key": "",
    "relay_id": "",
    "sentry_dsn": ""
  }'
  exit 0
fi

# Secret name in WorkOS Vault
SECRET_NAME="anysource-sentry-relay-credentials"

# Step 1: List all secrets to find the ID by name
LIST_RESPONSE=$(curl -sf "https://api.workos.com/vault/v1/kv" \
  -H "Authorization: Bearer ${API_KEY}" 2>&1 || echo "{}")

if [[ "$LIST_RESPONSE" == "{}" ]]; then
  echo "WARNING: Failed to connect to WorkOS Vault API - deploying without Sentry Relay" >&2
  # Return empty values to allow deployment without Sentry
  jq -n '{
    "public_key": "",
    "secret_key": "",
    "relay_id": "",
    "sentry_dsn": ""
  }'
  exit 0
fi

SECRET_ID=$(echo "$LIST_RESPONSE" | jq -r --arg name "$SECRET_NAME" \
  '.data[]? | select(.name == $name) | .id')

if [[ -z "$SECRET_ID" || "$SECRET_ID" == "null" ]]; then
  echo "WARNING: Secret '${SECRET_NAME}' not found in WorkOS Vault - deploying without Sentry Relay" >&2
  echo "NOTE: Contact Anysource support to provision relay credentials if you want Sentry telemetry" >&2
  # Return empty values to allow deployment without Sentry
  jq -n '{
    "public_key": "",
    "secret_key": "",
    "relay_id": "",
    "sentry_dsn": ""
  }'
  exit 0
fi

# Step 2: Retrieve the secret value
GET_RESPONSE=$(curl -sf "https://api.workos.com/vault/v1/kv/${SECRET_ID}" \
  -H "Authorization: Bearer ${API_KEY}" 2>&1 || echo "{}")

if [[ "$GET_RESPONSE" == "{}" ]]; then
  echo "WARNING: Failed to retrieve secret from WorkOS Vault - deploying without Sentry Relay" >&2
  # Return empty values to allow deployment without Sentry
  jq -n '{
    "public_key": "",
    "secret_key": "",
    "relay_id": "",
    "sentry_dsn": ""
  }'
  exit 0
fi

CREDENTIALS=$(echo "$GET_RESPONSE" | jq -r '.value // empty')

if [[ -z "$CREDENTIALS" ]]; then
  echo "WARNING: Secret value is empty - deploying without Sentry Relay" >&2
  # Return empty values to allow deployment without Sentry
  jq -n '{
    "public_key": "",
    "secret_key": "",
    "relay_id": "",
    "sentry_dsn": ""
  }'
  exit 0
fi

# Step 3: Parse and validate the JSON credentials
PUBLIC_KEY=$(echo "$CREDENTIALS" | jq -r '.public_key // empty')
SECRET_KEY=$(echo "$CREDENTIALS" | jq -r '.secret_key // empty')
RELAY_ID=$(echo "$CREDENTIALS" | jq -r '.id // empty')
SENTRY_DSN=$(echo "$CREDENTIALS" | jq -r '.sentry_dsn // empty')

if [[ -z "$PUBLIC_KEY" || -z "$SECRET_KEY" || -z "$RELAY_ID" ]]; then
  echo "WARNING: Invalid credentials format - deploying without Sentry Relay" >&2
  echo "NOTE: Expected format: {public_key, secret_key, id, sentry_dsn}" >&2
  # Return empty values to allow deployment without Sentry
  jq -n '{
    "public_key": "",
    "secret_key": "",
    "relay_id": "",
    "sentry_dsn": ""
  }'
  exit 0
fi

# Note: SENTRY_DSN is optional - can be overridden per environment

# Step 4: Output to Terraform as JSON (to stdout)
jq -n \
  --arg pk "$PUBLIC_KEY" \
  --arg sk "$SECRET_KEY" \
  --arg id "$RELAY_ID" \
  --arg dsn "$SENTRY_DSN" \
  '{
    "public_key": $pk,
    "secret_key": $sk,
    "relay_id": $id,
    "sentry_dsn": $dsn
  }'
