#!/bin/bash
# Capture deployment completion status and report to Sentry
# This script should be run AFTER applying changes to record success/failure
#
# NOTE: For ECS deployments, this script is now automatically invoked by Terraform!
#       See deployment-telemetry.tf in each ECS deployment directory.
#       Manual execution is only needed for:
#       - Kubernetes (Helm) deployments
#       - Reporting deployment failures
#
# See docs/deployment-guide.md for complete workflow documentation
#
# Usage Examples:
#   # Auto-detect infra_version from terraform.tfvars
#   ./infra/scripts/capture-deployment-completion.sh ecs <customer_id> success
#   ./infra/scripts/capture-deployment-completion.sh ecs <customer_id> failure "Error message"
#
#   # Explicit infra_version (useful for eks or when tfvars not available)
#   ./infra/scripts/capture-deployment-completion.sh ecs <customer_id> <infra_version> success
#   ./infra/scripts/capture-deployment-completion.sh eks <customer_id> <infra_version> failure "Error message"
#
# Required environment variables:
#   SENTRY_DSN - Sentry DSN for sending events to Sentry

set -euo pipefail

# =============================================================================
# Configuration and Validation
# =============================================================================

DEPLOYMENT_TYPE=${1:-}
CUSTOMER_ID=${2:-}
INFRA_VERSION=${3:-}
STATUS=${4:-}
ERROR_MESSAGE=${5:-}

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

# Handle different calling conventions by detecting if arg3 is version or status
# If arg3 looks like a version (matches X.Y.Z or is "unknown"), treat it as infra_version
# Otherwise treat it as status (for auto-detect version pattern)
if [ -n "$INFRA_VERSION" ]; then
    if [[ "$INFRA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ "$INFRA_VERSION" = "unknown" ]; then
        # Arg3 is a version: deployment_type customer_id version status [error_message]
        # Keep current assignments (already correct)
        :
    else
        # Arg3 is status (not a version): deployment_type customer_id status [error_message]
        # Shift arguments: arg3 is status, arg4 is error_message
        STATUS="$INFRA_VERSION"
        ERROR_MESSAGE="${4:-}"
        INFRA_VERSION=""
    fi
fi

if [ -z "$DEPLOYMENT_TYPE" ] || [ -z "$CUSTOMER_ID" ] || [ -z "$STATUS" ]; then
    log_error "Missing required arguments"
    echo ""
    echo "Usage: $0 <deployment_type> <customer_id> [infra_version] <status> [error_message]"
    echo ""
    echo "Arguments:"
    echo "  deployment_type: ecs or eks"
    echo "  customer_id: Customer identifier (e.g., acme-corp)"
    echo "  infra_version: (optional) Infrastructure version (e.g., 2.1.0)"
    echo "                 If not provided, will be auto-detected from terraform.tfvars for ECS"
    echo "  status: success or failure"
    echo "  error_message: (optional) Error details if status is failure"
    echo ""
    echo "Examples:"
    echo "  $0 ecs acme-corp success                    # Auto-detect version"
    echo "  $0 ecs acme-corp 2.1.0 success              # Explicit version"
    echo "  $0 ecs acme-corp failure 'Deployment failed'"
    echo "  $0 eks customer-demo 1.5.0 failure 'Timeout waiting for pods'"
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

if [ "$STATUS" != "success" ] && [ "$STATUS" != "failure" ]; then
    log_error "status must be 'success' or 'failure'"
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
            echo "   3. Pass infra_version as argument"
            exit 1
        fi
    else
        log_error "infra_version is required for eks deployments"
        echo "   Pass infra_version as argument"
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

# Helper function to display completion status without telemetry
display_completion_without_telemetry() {
    if [ "$STATUS" = "success" ]; then
        log_success "Deployment completed successfully for $CUSTOMER_ID (no telemetry)"
    else
        log_error "Deployment failed for $CUSTOMER_ID (no telemetry)"
        if [ -n "$ERROR_MESSAGE" ]; then
            echo "   Error: $ERROR_MESSAGE"
        fi
    fi
    echo ""
    log_info "Deployment status recorded locally (Sentry telemetry skipped)"
    exit 0
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
    echo ""
    display_completion_without_telemetry
fi

# Validate DSN format
if [[ ! "$SENTRY_DSN" =~ ^https?://[^@]+@[^/]+/[0-9]+$ ]]; then
    log_warning "Invalid SENTRY_DSN format - telemetry reporting disabled"
    echo "   Expected format: https://<key>@<host>/<project_id>"
    echo ""
    display_completion_without_telemetry
fi

# Apply defaults for optional environment variables
SENTRY_ORG="${SENTRY_ORG:-anysource-er}"
ENVIRONMENT="${ENVIRONMENT:-production}"

log_info "Capturing deployment completion..."
echo "Type: $DEPLOYMENT_TYPE"
echo "Customer: $CUSTOMER_ID"
echo "Infra Version: $INFRA_VERSION"
echo "Environment: $ENVIRONMENT"
echo "Status: $STATUS"
if [ -n "$ERROR_MESSAGE" ]; then
    echo "Error: $ERROR_MESSAGE"
fi
echo ""

# =============================================================================
# Setup
# =============================================================================

# Capture completion metadata
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_EPOCH=$(date +%s)
USER=$(whoami)
HOSTNAME=$(hostname)

# Try to read start timestamp for duration calculation
START_TIMESTAMP_FILE="/tmp/runlayer-deployments/${CUSTOMER_ID}-${DEPLOYMENT_TYPE}-start.json"
STARTED_AT=""
STARTED_AT_EPOCH=""
DURATION_MS=""

if [ -f "$START_TIMESTAMP_FILE" ]; then
    STARTED_AT=$(jq -r '.started_at // ""' "$START_TIMESTAMP_FILE" 2>/dev/null || echo "")
    STARTED_AT_EPOCH=$(jq -r '.started_at_epoch // ""' "$START_TIMESTAMP_FILE" 2>/dev/null || echo "")
    
    if [ -n "$STARTED_AT_EPOCH" ] && [ "$STARTED_AT_EPOCH" != "null" ]; then
        DURATION_MS=$(( (TIMESTAMP_EPOCH - STARTED_AT_EPOCH) * 1000 ))
        log_info "Deployment duration: ${DURATION_MS}ms ($(( DURATION_MS / 1000 ))s)"
    fi
    
    # Clean up start file after reading
    rm -f "$START_TIMESTAMP_FILE" 2>/dev/null || true
else
    # For EKS deployments, start timestamp is not available (only used for ECS)
    if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
        log_warning "Start timestamp not found - duration will not be calculated"
    fi
fi

# =============================================================================
# Send Completion Event to Sentry
# =============================================================================

# Create temporary directory for event
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Escape error message for JSON if present
if [ -n "$ERROR_MESSAGE" ]; then
    ERROR_MESSAGE_ESCAPED=$(echo "$ERROR_MESSAGE" | jq -Rs . || echo '""')
else
    ERROR_MESSAGE_ESCAPED='""'
fi

# =============================================================================
# Send Completion Event to Sentry
# =============================================================================

log_info "Sending deployment completion event to Sentry..."

# Extract project ID from DSN (with error handling)
PROJECT_ID=$(echo "$SENTRY_DSN" | grep -oE '/[0-9]+$' | tr -d '/' || echo "")
SENTRY_KEY=$(echo "$SENTRY_DSN" | grep -oE '://[^@]+' | sed 's|://||' || echo "")
SENTRY_HOST=$(echo "$SENTRY_DSN" | grep -oE '@[^/]+' | tr -d '@' || echo "")

# Verify we extracted all components
if [ -z "$PROJECT_ID" ] || [ -z "$SENTRY_KEY" ] || [ -z "$SENTRY_HOST" ]; then
    log_warning "Failed to parse SENTRY_DSN components - skipping telemetry"
    echo "   PROJECT_ID: ${PROJECT_ID:-missing}"
    echo "   SENTRY_KEY: ${SENTRY_KEY:-missing}"
    echo "   SENTRY_HOST: ${SENTRY_HOST:-missing}"
    echo ""
    if [ "$STATUS" = "success" ]; then
        log_success "Deployment completed successfully for $CUSTOMER_ID (telemetry skipped)"
    else
        log_error "Deployment failed for $CUSTOMER_ID (telemetry skipped)"
    fi
    exit 0
fi


# Build deployment metadata JSON with optional duration fields
DEPLOYMENT_METADATA_JSON=$(cat <<EOF
{
  "deployment_type": "$DEPLOYMENT_TYPE",
  "customer_id": "$CUSTOMER_ID",
  "infra_version": "$INFRA_VERSION",
  "environment": "$ENVIRONMENT",
  "timestamp": "$TIMESTAMP",
  "user": "$USER",
  "hostname": "$HOSTNAME",
  "status": "$STATUS",
  "error_message": $ERROR_MESSAGE_ESCAPED
EOF
)

# Add duration fields if available
if [ -n "$DURATION_MS" ]; then
    DEPLOYMENT_METADATA_JSON="${DEPLOYMENT_METADATA_JSON},
  \"duration_ms\": $DURATION_MS,
  \"started_at\": \"$STARTED_AT\",
  \"finished_at\": \"$TIMESTAMP\""
fi

DEPLOYMENT_METADATA_JSON="${DEPLOYMENT_METADATA_JSON}
}"

# Generate event and trace IDs
EVENT_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
TRACE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
SPAN_ID=$(openssl rand -hex 8)

# Calculate timestamps
TIMESTAMP_UNIX=$(date +%s)
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")

# Set start and end timestamps for the span
# Note: Sentry expects timestamps in seconds with microsecond precision (6 decimal places)
# Since we have epoch seconds as integers, we append .000000 to format them correctly
if [ -n "$DURATION_MS" ]; then
    # Use actual start time if available
    START_TIMESTAMP="${STARTED_AT_EPOCH}.000000"
    END_TIMESTAMP="${TIMESTAMP_UNIX}.000000"
else
    # Use current time for both if no duration
    START_TIMESTAMP="${TIMESTAMP_UNIX}.000000"
    END_TIMESTAMP="${TIMESTAMP_UNIX}.000000"
fi

# Construct Sentry transaction event (envelope format)
SENTRY_ENVELOPE_HEADER=$(cat <<EOF
{"event_id":"$EVENT_ID","sent_at":"$TIMESTAMP_ISO"}
EOF
)

SENTRY_TRANSACTION=$(cat <<EOF
{
  "type": "transaction",
  "event_id": "$EVENT_ID",
  "timestamp": $END_TIMESTAMP,
  "start_timestamp": $START_TIMESTAMP,
  "platform": "other",
  "transaction": "deployment.completion",
  "transaction_info": {
    "source": "custom"
  },
  "contexts": {
    "trace": {
      "trace_id": "$TRACE_ID",
      "span_id": "$SPAN_ID",
      "op": "deployment",
      "status": "$([ "$STATUS" = "success" ] && echo "ok" || echo "internal_error")"
    },
    "deployment": {
      "type": "$DEPLOYMENT_TYPE",
      "customer_id": "$CUSTOMER_ID",
      "environment": "$ENVIRONMENT",
      "timestamp": "$TIMESTAMP",
      "operator": "$USER",
      "hostname": "$HOSTNAME",
      "status": "$STATUS",
      "infra_version": "$INFRA_VERSION"
    }
  },
  "tags": {
    "customer_id": "$CUSTOMER_ID",
    "deployment_type": "$DEPLOYMENT_TYPE",
    "environment": "$ENVIRONMENT",
    "event_type": "deployment_completion",
    "deployment_status": "$STATUS",
    "initiated_by": "$USER",
    "infra_version": "$INFRA_VERSION"
  },
  "extra": {
    "deployment_metadata": $DEPLOYMENT_METADATA_JSON
  },
  "measurements": {},
  "spans": []
}
EOF
)

# Add duration measurement if available
if [ -n "$DURATION_MS" ]; then
    SENTRY_TRANSACTION=$(echo "$SENTRY_TRANSACTION" | jq --arg duration "$DURATION_MS" '.measurements.duration = {value: ($duration | tonumber), unit: "millisecond"}')
fi

# Create envelope (header + transaction)
SENTRY_ENVELOPE=$(printf "%s\n{\"type\":\"transaction\",\"length\":%d}\n%s\n" "$SENTRY_ENVELOPE_HEADER" "${#SENTRY_TRANSACTION}" "$SENTRY_TRANSACTION")

HTTP_CODE=$(printf "%s" "$SENTRY_ENVELOPE" | curl -s -w "%{http_code}" -o /tmp/sentry-response.txt -X POST "https://$SENTRY_HOST/api/$PROJECT_ID/envelope/" \
    -H "X-Sentry-Auth: Sentry sentry_key=$SENTRY_KEY, sentry_version=7" \
    -H "Content-Type: application/x-sentry-envelope" \
    --data-binary @- 2>&1 || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
    log_success "Deployment completion event sent to Sentry (HTTP $HTTP_CODE)"
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
    echo "   Deployment status: $STATUS (telemetry optional)"
fi

# =============================================================================
# Output Summary
# =============================================================================

echo ""

if [ "$STATUS" = "success" ]; then
    log_success "Infrastructure deployment completed successfully for $CUSTOMER_ID"
    echo ""
    log_info "View deployment in Sentry Discover:"
    echo "   All deployments: https://sentry.io/organizations/$SENTRY_ORG/discover/results/?field=title&field=event_type&field=customer_id&field=timestamp&query=event_type:deployment_completion&sort=-timestamp&statsPeriod=24h"
    echo "   This customer: https://sentry.io/organizations/$SENTRY_ORG/discover/results/?field=title&field=event_type&field=infra_version&field=timestamp&query=event_type:deployment_completion+customer_id:$CUSTOMER_ID&sort=-timestamp&statsPeriod=24h"
    echo "   This version: https://sentry.io/organizations/$SENTRY_ORG/discover/results/?field=title&field=customer_id&field=timestamp&query=event_type:deployment_completion+infra_version:$INFRA_VERSION&sort=-timestamp&statsPeriod=24h"
    echo ""
    log_info "Application events with this infra version:"
    echo "   https://sentry.io/organizations/$SENTRY_ORG/discover/results/?field=title&field=event.type&field=customer_id&field=timestamp&query=infra_version:$INFRA_VERSION+customer_id:$CUSTOMER_ID&sort=-timestamp&statsPeriod=24h"
else
    log_error "Infrastructure deployment failed for $CUSTOMER_ID"
    if [ -n "$ERROR_MESSAGE" ]; then
        echo ""
        echo "Error details:"
        echo "  $ERROR_MESSAGE"
    fi
    echo ""
    log_info "Investigate in Sentry Discover:"
    echo "   Failed deployments: https://sentry.io/organizations/$SENTRY_ORG/discover/results/?field=title&field=customer_id&field=error_message&field=timestamp&query=event_type:deployment_completion+deployment_status:failure&sort=-timestamp&statsPeriod=24h"
    echo "   This customer: https://sentry.io/organizations/$SENTRY_ORG/discover/results/?field=title&field=deployment_status&field=timestamp&query=event_type:deployment_completion+customer_id:$CUSTOMER_ID&sort=-timestamp&statsPeriod=24h"
    echo ""
    log_info "Common troubleshooting steps:"
    echo "   1. Review terraform/helm error logs"
    echo "   2. Check resource quotas and permissions"
    echo "   3. Verify configuration values"
    echo "   4. Review Sentry for related application errors"
fi

echo ""

# =============================================================================
# Post-Deployment Actions
# =============================================================================

if [ "$STATUS" = "success" ]; then
    log_info "Post-deployment recommendations:"
    echo "   1. Monitor application health in Sentry"
    echo "   2. Check for new errors: https://sentry.io/organizations/$SENTRY_ORG/issues/?query=is:unresolved+customer_id:$CUSTOMER_ID"
    echo "   3. Verify customer deployment is healthy"
    echo "   4. Update deployment documentation if needed"
    echo ""
    log_info "Note: App version (release) is separate from infra version"
    echo "   • infra_version=$INFRA_VERSION (infrastructure config - updated now)"
    echo "   • release=<app_version> (backend code - updated via CI/CD)"
    echo "   • deployment_type=$DEPLOYMENT_TYPE (ecs or eks)"
    echo "   • All tags will appear on application events from this customer"
    echo ""
fi
