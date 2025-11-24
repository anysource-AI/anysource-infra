#!/bin/bash
# Capture deployment telemetry (terraform/helm diffs) and report to Sentry
# This script should be run BEFORE applying changes to capture diffs
#
# See docs/deployment-guide.md for complete workflow documentation
#
# Usage Examples:
#   # Auto-detect infra_version from terraform.tfvars
#   ./infra/scripts/capture-deployment-telemetry.sh ecs <customer_id>
#
#   # Explicit infra_version (useful for eks or when tfvars not available)
#   ./infra/scripts/capture-deployment-telemetry.sh ecs <customer_id> <infra_version>
#   ./infra/scripts/capture-deployment-telemetry.sh eks <customer_id> <infra_version>
#
# Required environment variables:
#   SENTRY_DSN - Sentry DSN for sending events to Sentry
#
# Optional environment variables:
#   TERRAFORM_DIR - Directory to run terraform commands (defaults to current dir)
#   HELM_CHART - Path to helm chart (defaults to ./anysource-chart)
#   HELM_VALUES - Path to helm values file (defaults to values.yaml)
#   HELM_RELEASE_NAME - Helm release name (defaults to anysource-<customer_id>)
#   HELM_NAMESPACE - Helm namespace (defaults to anysource)

set -euo pipefail

# =============================================================================
# Configuration and Validation
# =============================================================================

DEPLOYMENT_TYPE=${1:-}
CUSTOMER_ID=${2:-}
INFRA_VERSION=${3:-}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

if [ -z "$DEPLOYMENT_TYPE" ] || [ -z "$CUSTOMER_ID" ]; then
    log_error "Missing required arguments"
    echo ""
    echo "Usage: $0 <deployment_type> <customer_id> [infra_version]"
    echo ""
    echo "Arguments:"
    echo "  deployment_type: ecs or eks"
    echo "  customer_id: Customer identifier (e.g., acme-corp)"
    echo "  infra_version: (optional) Infrastructure version (e.g., 2.1.0)"
    echo "                 If not provided, will be auto-detected from terraform.tfvars for ECS"
    echo ""
    echo "Examples:"
    echo "  $0 ecs acme-corp              # Auto-detect version from tfvars"
    echo "  $0 ecs acme-corp 2.1.0        # Explicit version"
    echo "  $0 eks customer-demo 1.5.0"
    echo ""
    echo "Environment variables:"
    echo "  SENTRY_DSN - For sending events to Sentry"
    echo "  SENTRY_ORG - Organization slug (default: anysource-er)"
    exit 1
fi

if [ "$DEPLOYMENT_TYPE" != "ecs" ] && [ "$DEPLOYMENT_TYPE" != "eks" ]; then
    log_error "deployment_type must be 'ecs' or 'eks'"
    exit 1
fi

# Auto-detect infra_version from terraform.tfvars if not provided
if [ -z "$INFRA_VERSION" ]; then
    if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
        TERRAFORM_DIR="${TERRAFORM_DIR:-.}"
        TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

        if [ -f "$TFVARS_FILE" ]; then
            INFRA_VERSION=$(grep '^infra_version' "$TFVARS_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
            if [ -z "$INFRA_VERSION" ]; then
                INFRA_VERSION="unknown"
                log_info "infra_version not found in terraform.tfvars, using default: unknown"
            elif [ "$INFRA_VERSION" != "unknown" ]; then
                log_info "Auto-detected infra_version from terraform.tfvars: $INFRA_VERSION"
            fi
        else
            log_error "terraform.tfvars not found at $TFVARS_FILE and no infra_version provided"
            echo "   Either:"
            echo "   1. Run from directory containing terraform.tfvars, or"
            echo "   2. Set TERRAFORM_DIR environment variable, or"
            echo "   3. Pass infra_version as third argument"
            exit 1
        fi
    else
        log_error "infra_version is required for eks deployments"
        echo "   Pass infra_version as third argument"
        exit 1
    fi
fi

# Validate version format (allow "unknown" as default)
if [ "$INFRA_VERSION" != "unknown" ] && ! [[ "$INFRA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "infra_version must follow format: MAJOR.MINOR.PATCH (e.g., 2.1.0) or 'unknown'"
    exit 1
fi

# =============================================================================
# Sentry Configuration
# =============================================================================

# Helper function to fetch SENTRY_DSN from WorkOS Vault
fetch_sentry_dsn_from_vault() {
    [ "$DEPLOYMENT_TYPE" != "ecs" ] && return 1

    local tfvars_file="${TERRAFORM_DIR:-.}/terraform.tfvars"
    [ ! -f "$tfvars_file" ] && return 1

    local auth_api_key
    auth_api_key=$(grep '^auth_api_key' "$tfvars_file" 2>/dev/null | cut -d'"' -f2 || echo "")
    [ -z "$auth_api_key" ] || [ "$auth_api_key" = "null" ] && return 1

    local vault_script
    vault_script="$(dirname "$0")/../aws-terraform-ecs/scripts/vault-fetch-relay.sh"
    [ ! -f "$vault_script" ] && return 1

    log_info "Fetching SENTRY_DSN from WorkOS Vault..."
    local vault_result
    vault_result=$(echo "{\"api_key\":\"$auth_api_key\"}" | bash "$vault_script" 2>/dev/null || echo "{}")

    local dsn
    dsn=$(echo "$vault_result" | jq -r '.sentry_dsn // empty' 2>/dev/null || echo "")

    if [ -n "$dsn" ]; then
        SENTRY_DSN="$dsn"
        log_success "SENTRY_DSN fetched from WorkOS Vault"
        return 0
    fi
    return 1
}

# Determine SENTRY_DSN and validate
if [ -n "${SENTRY_DSN:-}" ]; then
    log_info "Using SENTRY_DSN from environment variable"
elif fetch_sentry_dsn_from_vault; then
    : # DSN fetched successfully, already logged
else
    log_warning "SENTRY_DSN not available - telemetry reporting disabled"
    echo "   To enable Sentry telemetry:"
    echo "   1. Set SENTRY_DSN environment variable, or"
    echo "   2. Ensure WorkOS Vault contains 'runlayer-sentry-credentials' with sentry_dsn field"
    echo "   Deployment diff will still be captured and displayed"
    echo ""
    SENTRY_ENABLED=false
fi

# Validate DSN format
if [ -n "${SENTRY_DSN:-}" ] && [[ ! "$SENTRY_DSN" =~ ^https?://[^@]+@[^/]+/[0-9]+$ ]]; then
    log_warning "Invalid SENTRY_DSN format - telemetry reporting disabled"
    echo "   Expected format: https://<key>@<host>/<project_id>"
    echo "   Deployment diff will still be captured and displayed"
    echo ""
    SENTRY_ENABLED=false
fi

# Set final status
SENTRY_ENABLED="${SENTRY_ENABLED:-true}"

# Apply defaults for optional environment variables
SENTRY_ORG="${SENTRY_ORG:-anysource-er}"
ENVIRONMENT="${ENVIRONMENT:-production}"

log_info "Capturing deployment telemetry..."
echo "Type: $DEPLOYMENT_TYPE"
echo "Customer: $CUSTOMER_ID"
echo "Infra Version: $INFRA_VERSION"
echo "Environment: $ENVIRONMENT"
echo "Sentry: $([ "$SENTRY_ENABLED" = true ] && echo 'enabled' || echo 'disabled')"
echo ""

# =============================================================================
# Setup
# =============================================================================

# Create temporary directory for diff output
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

DIFF_FILE_TEXT="$TEMP_DIR/deployment-diff.txt"
DIFF_FILE_JSON="$TEMP_DIR/deployment-diff.json"
METADATA_FILE="$TEMP_DIR/metadata.json"
CHANGES_SUMMARY_FILE="$TEMP_DIR/changes-summary.json"
START_TIMESTAMP_FILE="$TEMP_DIR/deployment-start.json"

# Capture deployment metadata
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_EPOCH=$(date +%s)
USER=$(whoami)
HOSTNAME=$(hostname)
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Write start timestamp for duration calculation (always write, even if Sentry disabled)
cat > "$START_TIMESTAMP_FILE" <<EOF
{
  "started_at": "$TIMESTAMP",
  "started_at_epoch": $TIMESTAMP_EPOCH,
  "customer_id": "$CUSTOMER_ID",
  "deployment_type": "$DEPLOYMENT_TYPE",
  "infra_version": "$INFRA_VERSION",
  "environment": "$ENVIRONMENT"
}
EOF

# Copy to a persistent location for completion script to read
mkdir -p /tmp/runlayer-deployments 2>/dev/null || true
cp "$START_TIMESTAMP_FILE" "/tmp/runlayer-deployments/${CUSTOMER_ID}-${DEPLOYMENT_TYPE}-start.json" 2>/dev/null || true

# =============================================================================
# Capture Diff Based on Deployment Type
# =============================================================================

if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
    log_info "Generating terraform plan..."

    TERRAFORM_DIR="${TERRAFORM_DIR:-.}"

    cd "$TERRAFORM_DIR"

    # Generate terraform plan
    if ! terraform plan -no-color -out=tfplan > "$DIFF_FILE_TEXT" 2>&1; then
        log_error "Terraform plan failed"
        cat "$DIFF_FILE_TEXT"
        exit 1
    fi

    log_success "Terraform plan generated"

    # Convert plan to JSON for structured parsing
    log_info "Converting plan to JSON..."
    if ! terraform show -json tfplan > "$DIFF_FILE_JSON" 2>&1; then
        log_warning "Failed to generate JSON output, falling back to text parsing"

        # Fallback: parse text output
        RESOURCES_TO_ADD=$(grep -c "will be created" "$DIFF_FILE_TEXT" || echo "0")
        RESOURCES_TO_CHANGE=$(grep -c "will be updated" "$DIFF_FILE_TEXT" || echo "0")
        RESOURCES_TO_DESTROY=$(grep -c "will be destroyed" "$DIFF_FILE_TEXT" || echo "0")
        echo "{}" > "$CHANGES_SUMMARY_FILE"
    else
        log_success "JSON plan generated"

        # Parse JSON for accurate resource counts
        RESOURCES_TO_ADD=$(jq -r '.resource_changes[] | select(.change.actions[] == "create") | .address' "$DIFF_FILE_JSON" 2>/dev/null | wc -l | tr -d ' ')
        RESOURCES_TO_CHANGE=$(jq -r '.resource_changes[] | select(.change.actions[] == "update") | .address' "$DIFF_FILE_JSON" 2>/dev/null | wc -l | tr -d ' ')
        RESOURCES_TO_DESTROY=$(jq -r '.resource_changes[] | select(.change.actions[] == "delete") | .address' "$DIFF_FILE_JSON" 2>/dev/null | wc -l | tr -d ' ')

        # Extract detailed changes summary
        jq '{
            resource_changes: [
                .resource_changes[] | {
                    address: .address,
                    type: .type,
                    provider_name: .provider_name,
                    actions: .change.actions,
                    before_sensitive: .change.before_sensitive,
                    after_sensitive: .change.after_sensitive
                }
            ],
            output_changes: .output_changes
        }' "$DIFF_FILE_JSON" > "$CHANGES_SUMMARY_FILE" 2>/dev/null || echo "{}" > "$CHANGES_SUMMARY_FILE"
    fi

elif [ "$DEPLOYMENT_TYPE" = "eks" ]; then
    log_info "Generating helm diff..."

    # Configuration with defaults
    HELM_CHART="${HELM_CHART:-./anysource-chart}"
    HELM_VALUES="${HELM_VALUES:-values.yaml}"
    HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-anysource-${CUSTOMER_ID}}"
    HELM_NAMESPACE="${HELM_NAMESPACE:-anysource}"

    # Check if helm diff plugin is installed
    if ! helm plugin list | grep -q "^diff"; then
        log_info "Installing helm-diff plugin..."
        helm plugin install https://github.com/databus23/helm-diff
    fi

    # Generate helm diff - try JSON first, fallback to text
    if helm diff upgrade "$HELM_RELEASE_NAME" "$HELM_CHART" \
        --namespace "$HELM_NAMESPACE" \
        --values "$HELM_VALUES" \
        --output json > "$DIFF_FILE_JSON" 2>&1; then

        log_success "Helm diff (JSON) generated"

        # Parse JSON output
        # Note: helm-diff JSON format varies by version, handle gracefully
        if jq -e . "$DIFF_FILE_JSON" >/dev/null 2>&1; then
            RESOURCES_TO_ADD=$(jq -r 'select(.changes != null) | .changes[] | select(.action == "add") | .name' "$DIFF_FILE_JSON" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
            RESOURCES_TO_CHANGE=$(jq -r 'select(.changes != null) | .changes[] | select(.action == "modify") | .name' "$DIFF_FILE_JSON" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
            RESOURCES_TO_DESTROY=$(jq -r 'select(.changes != null) | .changes[] | select(.action == "delete") | .name' "$DIFF_FILE_JSON" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
        else
            log_warning "JSON output invalid, falling back to text mode"
            RESOURCES_TO_ADD=0
            RESOURCES_TO_CHANGE=0
            RESOURCES_TO_DESTROY=0
        fi
    else
        # Fallback to text output
        log_info "JSON diff not supported, using text output"

        helm diff upgrade "$HELM_RELEASE_NAME" "$HELM_CHART" \
            --namespace "$HELM_NAMESPACE" \
            --values "$HELM_VALUES" \
            --no-color > "$DIFF_FILE_TEXT" 2>&1 || true

        log_success "Helm diff (text) generated"

        # Parse text output
        RESOURCES_TO_ADD=$(grep -c "^+" "$DIFF_FILE_TEXT" 2>/dev/null || echo "0")
        RESOURCES_TO_CHANGE=$(grep -c "^~" "$DIFF_FILE_TEXT" 2>/dev/null || echo "0")
        RESOURCES_TO_DESTROY=$(grep -c "^-" "$DIFF_FILE_TEXT" 2>/dev/null || echo "0")
    fi

    # Create changes summary
    echo "{\"helm_release\": \"$HELM_RELEASE_NAME\", \"namespace\": \"$HELM_NAMESPACE\"}" > "$CHANGES_SUMMARY_FILE"
fi

# Check if there are any changes
TOTAL_CHANGES=$((RESOURCES_TO_ADD + RESOURCES_TO_CHANGE + RESOURCES_TO_DESTROY))

if [ "$TOTAL_CHANGES" = "0" ]; then
    log_info "No infrastructure changes detected"
    HAS_CHANGES=false
else
    log_success "Changes detected:"
    echo "   Add: $RESOURCES_TO_ADD resources"
    echo "   Change: $RESOURCES_TO_CHANGE resources"
    echo "   Destroy: $RESOURCES_TO_DESTROY resources"
    HAS_CHANGES=true
fi

# =============================================================================
# Create Metadata and Send to Sentry
# =============================================================================

# Create metadata JSON
cat > "$METADATA_FILE" <<EOF
{
  "deployment_type": "$DEPLOYMENT_TYPE",
  "customer_id": "$CUSTOMER_ID",
  "infra_version": "$INFRA_VERSION",
  "environment": "$ENVIRONMENT",
  "timestamp": "$TIMESTAMP",
  "user": "$USER",
  "hostname": "$HOSTNAME",
  "git_commit": "$GIT_COMMIT",
  "git_commit_short": "$GIT_COMMIT_SHORT",
  "git_branch": "$GIT_BRANCH",
  "has_changes": $HAS_CHANGES,
  "resources_to_add": $RESOURCES_TO_ADD,
  "resources_to_change": $RESOURCES_TO_CHANGE,
  "resources_to_destroy": $RESOURCES_TO_DESTROY,
  "total_changes": $TOTAL_CHANGES
}
EOF

# Send deployment change event to Sentry if there are changes
if [ "$SENTRY_ENABLED" = true ] && [ "$HAS_CHANGES" = true ]; then
    log_info "Sending deployment change event to Sentry..."

    # Read the diff content (truncate if too large)
    # Check which diff file exists and use that for telemetry
    if [ -f "$DIFF_FILE_TEXT" ]; then
        DIFF_CONTENT=$(head -c 8000 "$DIFF_FILE_TEXT" 2>/dev/null || echo "Diff content unavailable")
        if [ "$(wc -c < "$DIFF_FILE_TEXT")" -gt 8000 ]; then
            DIFF_CONTENT="$DIFF_CONTENT\n\n... (truncated, full diff too large)"
        fi
    elif [ -f "$DIFF_FILE_JSON" ]; then
        DIFF_CONTENT=$(head -c 8000 "$DIFF_FILE_JSON" 2>/dev/null || echo "Diff content unavailable")
        if [ "$(wc -c < "$DIFF_FILE_JSON")" -gt 8000 ]; then
            DIFF_CONTENT="$DIFF_CONTENT\n\n... (truncated, full diff too large)"
        fi
    else
        DIFF_CONTENT="Diff content unavailable"
    fi

    # Escape the diff content for JSON using jq (more reliable than python)
    DIFF_CONTENT_ESCAPED=$(echo "$DIFF_CONTENT" | jq -Rs . 2>/dev/null || echo '"[Content unavailable]"')

    # Extract project ID from DSN
    PROJECT_ID=$(echo "$SENTRY_DSN" | grep -oE '/[0-9]+$' | tr -d '/' || echo "")
    SENTRY_KEY=$(echo "$SENTRY_DSN" | grep -oE '://[^@]+' | sed 's|://||' || echo "")
    SENTRY_HOST=$(echo "$SENTRY_DSN" | grep -oE '@[^/]+' | tr -d '@' || echo "")

    # Verify we extracted all components
    if [ -z "$PROJECT_ID" ] || [ -z "$SENTRY_KEY" ] || [ -z "$SENTRY_HOST" ]; then
        log_warning "Failed to parse SENTRY_DSN - skipping telemetry"
        SENTRY_ENABLED=false
    fi
fi

if [ "$SENTRY_ENABLED" = true ] && [ "$HAS_CHANGES" = true ]; then
    # Generate event and trace IDs
    EVENT_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
    TRACE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
    SPAN_ID=$(openssl rand -hex 8)

    # Calculate timestamps
    # Note: Sentry expects timestamps in seconds with microsecond precision (6 decimal places)
    # Since we have epoch seconds as integers, we append .000000 to format them correctly
    TIMESTAMP_UNIX=$(date +%s)
    TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")
    TIMESTAMP_FLOAT="${TIMESTAMP_UNIX}.000000"

    # Construct Sentry transaction event (envelope format)
    SENTRY_ENVELOPE_HEADER=$(cat <<EOF
{"event_id":"$EVENT_ID","sent_at":"$TIMESTAMP_ISO"}
EOF
)

    SENTRY_TRANSACTION=$(cat <<EOF
{
  "type": "transaction",
  "event_id": "$EVENT_ID",
  "timestamp": $TIMESTAMP_FLOAT,
  "start_timestamp": $TIMESTAMP_FLOAT,
  "platform": "other",
  "transaction": "deployment.change",
  "transaction_info": {
    "source": "custom"
  },
  "contexts": {
    "trace": {
      "trace_id": "$TRACE_ID",
      "span_id": "$SPAN_ID",
      "op": "deployment.plan",
      "status": "ok"
    },
    "deployment": {
      "type": "$DEPLOYMENT_TYPE",
      "customer_id": "$CUSTOMER_ID",
      "environment": "$ENVIRONMENT",
      "timestamp": "$TIMESTAMP",
      "operator": "$USER",
      "hostname": "$HOSTNAME",
      "infra_version": "$INFRA_VERSION"
    }
  },
  "tags": {
    "customer_id": "$CUSTOMER_ID",
    "deployment_type": "$DEPLOYMENT_TYPE",
    "environment": "$ENVIRONMENT",
    "event_type": "deployment_change",
    "has_changes": "true",
    "initiated_by": "$USER",
    "infra_version": "$INFRA_VERSION"
  },
  "extra": {
    "deployment_metadata": $(cat "$METADATA_FILE"),
    "summary": {
      "resources_to_add": $RESOURCES_TO_ADD,
      "resources_to_change": $RESOURCES_TO_CHANGE,
      "resources_to_destroy": $RESOURCES_TO_DESTROY,
      "total_changes": $TOTAL_CHANGES,
      "changes_preview": $DIFF_CONTENT_ESCAPED
    }
  },
  "measurements": {
    "resources_to_add": {
      "value": $RESOURCES_TO_ADD,
      "unit": "none"
    },
    "resources_to_change": {
      "value": $RESOURCES_TO_CHANGE,
      "unit": "none"
    },
    "resources_to_destroy": {
      "value": $RESOURCES_TO_DESTROY,
      "unit": "none"
    }
  },
  "spans": []
}
EOF
)

    # Create envelope (header + transaction)
    SENTRY_ENVELOPE=$(printf "%s\n{\"type\":\"transaction\",\"length\":%d}\n%s\n" "$SENTRY_ENVELOPE_HEADER" "${#SENTRY_TRANSACTION}" "$SENTRY_TRANSACTION")

    HTTP_CODE=$(printf "%s" "$SENTRY_ENVELOPE" | curl -s -w "%{http_code}" -o /tmp/sentry-response.txt -X POST "https://$SENTRY_HOST/api/$PROJECT_ID/envelope/" \
        -H "X-Sentry-Auth: Sentry sentry_key=$SENTRY_KEY, sentry_version=7" \
        -H "Content-Type: application/x-sentry-envelope" \
        --data-binary @- 2>&1 || echo "000")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
        log_success "Deployment change event sent to Sentry (HTTP $HTTP_CODE)"
        EVENT_ID=$(cat /tmp/sentry-response.txt 2>/dev/null | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ -n "$EVENT_ID" ]; then
            echo "   Event ID: $EVENT_ID"
        fi
    else
        log_warning "Failed to send telemetry to Sentry (HTTP $HTTP_CODE)"
        if [ "$HTTP_CODE" = "000" ]; then
            echo "   Could not connect to Sentry - check network connectivity"
        else
            echo "   Response: $(cat /tmp/sentry-response.txt 2>/dev/null || echo 'No response')"
        fi
        echo "   Deployment diff captured successfully (telemetry optional)"
    fi
fi

# =============================================================================
# Output Summary
# =============================================================================

echo ""
log_info "Deployment Diff Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$DIFF_FILE_TEXT" ]; then
    cat "$DIFF_FILE_TEXT"
elif [ -f "$DIFF_FILE_JSON" ]; then
    jq -C '.' "$DIFF_FILE_JSON" 2>/dev/null || cat "$DIFF_FILE_JSON"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$HAS_CHANGES" = true ]; then
    log_warning "IMPORTANT: Review the diff above before applying changes"
    echo ""
    echo "To apply these changes:"
    if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
        echo "  terraform apply tfplan"
    else
        echo "  helm upgrade $HELM_RELEASE_NAME $HELM_CHART --namespace $HELM_NAMESPACE --values $HELM_VALUES"
    fi

    if [ "$SENTRY_ENABLED" = true ]; then
        echo ""
        log_info "View in Sentry:"
        echo "   https://sentry.io/organizations/$SENTRY_ORG/issues/?query=event_type:deployment_change+customer_id:$CUSTOMER_ID"
    fi
else
    log_success "No changes to apply"
fi

echo ""
