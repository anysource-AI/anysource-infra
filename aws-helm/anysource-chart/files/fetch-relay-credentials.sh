#!/bin/sh
#
# Fetch Sentry Relay credentials from WorkOS Vault and write to files
#
# This script is executed by an init container in the relay deployment.
# It fetches relay credentials from WorkOS Vault and writes them to a shared volume.
#
# Environment variables (required):
#   WORKOS_API_KEY          - WorkOS API key for vault access
#
# Environment variables (optional):
#   WORKOS_API_BASE         - WorkOS API base URL (default: https://api.workos.com)
#   WORKOS_VAULT_SECRET_NAME - Secret name in WorkOS Vault (default: runlayer-sentry-credentials)
#   CREDENTIALS_DIR         - Directory to write credential files (default: /credentials)
#
# Output files (in CREDENTIALS_DIR):
#   public_key  - Relay public key
#   secret_key  - Relay secret key
#   id          - Relay ID
#
# Exit codes:
#   0 - Success (credentials written or gracefully skipped if unavailable)
#   1 - Fatal error (missing prerequisites, invalid input)

set -euo pipefail

# Default values
: "${WORKOS_API_BASE:=https://api.workos.com}"
: "${WORKOS_VAULT_SECRET_NAME:=runlayer-sentry-credentials}"
: "${CREDENTIALS_DIR:=/credentials}"

# Function to install dependencies based on available package manager
install_dependencies() {
    local deps="curl jq ca-certificates"

    # Check if dependencies are already installed
    local missing_deps=""
    for dep in curl jq; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps="$missing_deps $dep"
        fi
    done

    # All dependencies present, nothing to do
    if [ -z "$missing_deps" ]; then
        echo "Required tools already installed" >&2
        return 0
    fi

    echo "Installing required tools:$missing_deps..." >&2

    # Try Alpine (apk)
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache $deps >/dev/null 2>&1 || {
            echo "Error: Failed to install required tools using apk" >&2
            return 1
        }
        return 0
    fi

    # Try Debian/Ubuntu (apt-get)
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1 && \
        apt-get install -y curl jq ca-certificates >/dev/null 2>&1 || {
            echo "Error: Failed to install required tools using apt-get" >&2
            return 1
        }
        return 0
    fi

    # Try Red Hat/CentOS (yum)
    if command -v yum >/dev/null 2>&1; then
        yum install -y curl jq ca-certificates >/dev/null 2>&1 || {
            echo "Error: Failed to install required tools using yum" >&2
            return 1
        }
        return 0
    fi

    # No supported package manager found
    echo "Error: No supported package manager found (tried: apk, apt-get, yum)" >&2
    echo "Please install curl and jq manually" >&2
    return 1
}

install_dependencies

# Validate required environment variables
if [ -z "${WORKOS_API_KEY:-}" ]; then
    echo "Error: WORKOS_API_KEY environment variable is required" >&2
    exit 1
fi

echo "Fetching Sentry Relay credentials from WorkOS Vault..." >&2

# Curl options with retries and timeouts
CURL_OPTS="--fail --show-error --silent --connect-timeout 5 --max-time 25 --retry 3 --retry-all-errors"

# Function to write empty credentials and exit gracefully
# Args: $1 = reason message for config.yml comment
write_empty_credentials_and_exit() {
    local reason="$1"
    mkdir -p "$CREDENTIALS_DIR"

    # Write empty credentials.json (required by Relay in managed mode)
    cat > "${CREDENTIALS_DIR}/credentials.json" <<EOF
{
  "secret_key": "",
  "public_key": "",
  "id": ""
}
EOF

    # Write minimal config.yml with explanatory comment
    cat > "${CREDENTIALS_DIR}/config.yml" <<EOF
relay:
  # No credentials available - ${reason}
EOF

    exit 0
}

# Step 1: List all secrets to find the ID by name
LIST_RESPONSE=$(curl ${CURL_OPTS} \
    -H "Authorization: Bearer ${WORKOS_API_KEY}" \
    "${WORKOS_API_BASE}/vault/v1/kv" 2>/dev/null || echo "{}")

if [ "$LIST_RESPONSE" = "{}" ]; then
    echo "Warning: Failed to connect to WorkOS Vault API - relay will start without credentials" >&2
    write_empty_credentials_and_exit "failed to connect to WorkOS Vault API"
fi

SECRET_ID=$(echo "$LIST_RESPONSE" | jq -r --arg name "$WORKOS_VAULT_SECRET_NAME" \
    '.data[]? | select(.name == $name) | .id')

if [ -z "$SECRET_ID" ] || [ "$SECRET_ID" = "null" ]; then
    echo "Warning: Secret '${WORKOS_VAULT_SECRET_NAME}' not found in WorkOS Vault" >&2
    echo "Note: Contact Runlayer support to provision relay credentials" >&2
    write_empty_credentials_and_exit "secret not found in WorkOS Vault"
fi

# Step 2: Retrieve the secret value
GET_RESPONSE=$(curl ${CURL_OPTS} \
    -H "Authorization: Bearer ${WORKOS_API_KEY}" \
    "${WORKOS_API_BASE}/vault/v1/kv/${SECRET_ID}" 2>/dev/null || echo "{}")

if [ "$GET_RESPONSE" = "{}" ]; then
    echo "Warning: Failed to retrieve secret from WorkOS Vault" >&2
    write_empty_credentials_and_exit "failed to retrieve secret from WorkOS Vault"
fi

CREDENTIALS=$(echo "$GET_RESPONSE" | jq -r '.value // empty')

if [ -z "$CREDENTIALS" ]; then
    echo "Warning: Secret value is empty" >&2
    write_empty_credentials_and_exit "secret value is empty"
fi

# Step 3: Parse and validate the JSON credentials
PUBLIC_KEY=$(echo "$CREDENTIALS" | jq -r '.public_key // empty')
SECRET_KEY=$(echo "$CREDENTIALS" | jq -r '.secret_key // empty')
RELAY_ID=$(echo "$CREDENTIALS" | jq -r '.id // empty')

if [ -z "$PUBLIC_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$RELAY_ID" ]; then
    echo "Warning: Invalid credentials format - missing required fields" >&2
    echo "Expected format: {public_key, secret_key, id}" >&2
    write_empty_credentials_and_exit "invalid credentials format"
fi

# Step 4: Write credentials to files
echo "Writing credentials to ${CREDENTIALS_DIR}..." >&2

mkdir -p "$CREDENTIALS_DIR"

# Write credentials.json in Relay's expected format
cat > "${CREDENTIALS_DIR}/credentials.json" <<EOF
{
  "secret_key": "$SECRET_KEY",
  "public_key": "$PUBLIC_KEY",
  "id": "$RELAY_ID"
}
EOF

# Write minimal config.yml (required by Relay when using --config flag)
# Most settings will be overridden by environment variables
cat > "${CREDENTIALS_DIR}/config.yml" <<EOF
relay:
  # Config managed by environment variables
  # This minimal config file is required for Relay to start
EOF

# Mask sensitive data in logs
RELAY_ID_MASKED="${RELAY_ID:0:8}..."
echo "✓ Successfully fetched and wrote relay credentials (ID: ${RELAY_ID_MASKED})" >&2
exit 0
