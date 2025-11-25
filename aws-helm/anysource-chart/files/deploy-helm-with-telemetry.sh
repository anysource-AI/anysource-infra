#!/usr/bin/env bash
#
# deploy-helm-with-telemetry.sh
#
# Wrapper script that automates Helm deployment with deployment telemetry.
# This script runs helm upgrade and reports completion status to Sentry.
#
# Usage:
#   ./scripts/deploy-helm-with-telemetry.sh [customer_id] [infra_version] [helm-flags...]
#
# Examples:
#   # Auto-detect customer_id and infra_version from values YAML
#   ./scripts/deploy-helm-with-telemetry.sh auto auto -f production-values.yaml
#
#   # Explicit customer_id and infra_version
#   ./scripts/deploy-helm-with-telemetry.sh acme-corp 2.1.0 -f production-values.yaml
#
#   # With custom settings
#   HELM_CHART=./my-chart HELM_NAMESPACE=prod \
#     ./scripts/deploy-helm-with-telemetry.sh auto auto \
#     --set global.deployment.customerId=acme-corp \
#     --set global.deployment.infraVersion=2.1.0
#
# Environment Variables:
#   SENTRY_DSN                - (Optional) Sentry DSN for telemetry. Auto-detected from values YAML if not set
#   ENVIRONMENT               - (Optional) Environment name (default: production)
#   DEPLOY_TELEMETRY_DIFF     - (Optional) Set to "true" to enable pre-deploy diff telemetry (default: false, only sends completion)
#   HELM_CHART                - (Optional) Path to Helm chart (default: ./infra/aws-helm/anysource-chart)
#   HELM_VALUES               - (Optional) Path to values file (default: values.yaml)
#   HELM_NAMESPACE            - (Optional) Kubernetes namespace (default: anysource)
#   HELM_RELEASE_NAME         - (Optional) Helm release name (default: anysource)
#
# See docs/deployment-guide.md for complete documentation

set -euo pipefail

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

# =============================================================================
# Argument Validation
# =============================================================================

CUSTOMER_ID="${1:-auto}"
INFRA_VERSION="${2:-auto}"

# Shift arguments if provided, otherwise keep all for helm
if [ $# -ge 2 ]; then
    shift 2
fi

# =============================================================================
# Configuration
# =============================================================================

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper function to resolve script paths (chart files/ first, then repo paths)
resolve_script_path() {
    local script_name="$1"

    # Try chart files/ directory first (for packaged chart usage)
    if [ -f "$SCRIPT_DIR/../files/$script_name" ]; then
        echo "$SCRIPT_DIR/../files/$script_name"
    # Fall back to repo infra/scripts/ (for repo usage)
    elif [ -f "$SCRIPT_DIR/../../../scripts/$script_name" ]; then
        echo "$SCRIPT_DIR/../../../scripts/$script_name"
    else
        log_error "Script not found: $script_name"
        echo "   Searched:"
        echo "   - $SCRIPT_DIR/../files/$script_name (chart files)"
        echo "   - $SCRIPT_DIR/../../../scripts/$script_name (repo scripts)"
        exit 1
    fi
}

CAPTURE_TELEMETRY_SCRIPT=$(resolve_script_path "capture-deployment-telemetry.sh")
CAPTURE_COMPLETION_SCRIPT=$(resolve_script_path "capture-deployment-completion.sh")

# Helm configuration with defaults (relative to infra/aws-helm)
HELM_CHART="${HELM_CHART:-./anysource-chart}"
HELM_VALUES="${HELM_VALUES:-values.yaml}"
HELM_NAMESPACE="${HELM_NAMESPACE:-anysource}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-anysource}"
ENVIRONMENT="${ENVIRONMENT:-production}"
DEPLOY_TELEMETRY_DIFF="${DEPLOY_TELEMETRY_DIFF:-false}"

# =============================================================================
# Auto-detect customer_id and infra_version from Helm values if set to "auto"
# =============================================================================

if [ "$CUSTOMER_ID" = "auto" ] || [ "$INFRA_VERSION" = "auto" ] || [ -z "${SENTRY_DSN:-}" ]; then
    log_info "Auto-detecting values from Helm values file: $HELM_VALUES"

    # Check if values file exists
    if [ ! -f "$HELM_VALUES" ]; then
        log_error "Values file not found: $HELM_VALUES"
        echo "   Cannot auto-detect customer_id, infra_version, or SENTRY_DSN"
        echo "   Either:"
        echo "   1. Provide explicit customer_id and infra_version as arguments, or"
        echo "   2. Ensure HELM_VALUES points to a valid values file"
        exit 1
    fi

    # Auto-detect customer_id from global.domain
    if [ "$CUSTOMER_ID" = "auto" ]; then
        CUSTOMER_ID=$(yq eval '.global.domain // ""' "$HELM_VALUES" 2>/dev/null || echo "")
        if [ -z "$CUSTOMER_ID" ]; then
            log_error "Could not auto-detect customer_id from global.domain in $HELM_VALUES"
            echo "   Either:"
            echo "   1. Add 'global.domain' to your values file, or"
            echo "   2. Pass customer_id explicitly as first argument"
            exit 1
        fi
        log_info "Auto-detected customer_id from global.domain: $CUSTOMER_ID"
    fi

    # Auto-detect infra_version from global.deployment.infraVersion (if exists, otherwise use "unknown")
    if [ "$INFRA_VERSION" = "auto" ]; then
        INFRA_VERSION=$(yq eval '.global.deployment.infraVersion // ""' "$HELM_VALUES" 2>/dev/null || echo "")
        if [ -z "$INFRA_VERSION" ]; then
            INFRA_VERSION="unknown"
            log_info "infra_version not found in global.deployment.infraVersion, using: unknown"
        else
            log_info "Auto-detected infra_version from global.deployment.infraVersion: $INFRA_VERSION"
        fi
    fi

    # Auto-detect SENTRY_DSN from backend.secrets.SENTRY_DSN if not set in environment
    if [ -z "${SENTRY_DSN:-}" ]; then
        SENTRY_DSN=$(yq eval '.backend.secrets.SENTRY_DSN // ""' "$HELM_VALUES" 2>/dev/null || echo "")
        if [ -n "$SENTRY_DSN" ]; then
            log_info "Auto-detected SENTRY_DSN from backend.secrets.SENTRY_DSN"
        else
            log_warning "SENTRY_DSN not found in environment or values file - telemetry disabled"
        fi
    fi
fi

# Validate version format (allow "unknown" as default)
if [ "$INFRA_VERSION" != "unknown" ] && ! [[ "$INFRA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "infra_version must follow format: MAJOR.MINOR.PATCH (e.g., 2.1.0) or 'unknown'"
    exit 1
fi

log_info "Helm Deployment with Telemetry"
echo "Customer: $CUSTOMER_ID"
echo "Infra Version: $INFRA_VERSION"
echo "Environment: $ENVIRONMENT"
echo "Chart: $HELM_CHART"
echo "Values: $HELM_VALUES"
echo "Namespace: $HELM_NAMESPACE"
echo "Release: $HELM_RELEASE_NAME"
echo "Telemetry Diff: $DEPLOY_TELEMETRY_DIFF"
echo ""

# =============================================================================
# Pre-Deployment Telemetry (Optional - gated by DEPLOY_TELEMETRY_DIFF)
# =============================================================================

if [ "$DEPLOY_TELEMETRY_DIFF" = "true" ]; then
    log_info "Capturing pre-deployment telemetry (diff)..."

    # Set environment variables for telemetry scripts
    export HELM_CHART
    export HELM_VALUES
    export HELM_NAMESPACE
    export HELM_RELEASE_NAME
    export ENVIRONMENT

    # Capture deployment diff and send to Sentry
    if ! bash "$CAPTURE_TELEMETRY_SCRIPT" eks "$CUSTOMER_ID" "$INFRA_VERSION"; then
        log_warning "Failed to capture deployment telemetry (continuing anyway)"
    fi

    echo ""
else
    log_info "Pre-deployment diff telemetry disabled (set DEPLOY_TELEMETRY_DIFF=true to enable)"
    echo ""
fi

# =============================================================================
# Helm Deployment
# =============================================================================

log_info "Running Helm deployment..."
echo "Command: helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART"
echo "  --namespace $HELM_NAMESPACE"
echo "  --create-namespace"
echo "  --values $HELM_VALUES"
for arg in "$@"; do
    echo "  $arg"
done
echo ""

# Run helm upgrade with all passed flags
# Disable exit on error to capture exit code
set +e
helm upgrade --install "$HELM_RELEASE_NAME" "$HELM_CHART" \
    --namespace "$HELM_NAMESPACE" \
    --create-namespace \
    --values "$HELM_VALUES" \
    "$@"
HELM_EXIT_CODE=$?
set -e

echo ""

# =============================================================================
# Post-Deployment Telemetry
# =============================================================================

if [ $HELM_EXIT_CODE -eq 0 ]; then
    log_success "Helm deployment completed successfully"
    echo ""

    log_info "Capturing deployment completion..."
    if ! bash "$CAPTURE_COMPLETION_SCRIPT" eks "$CUSTOMER_ID" "$INFRA_VERSION" success; then
        log_warning "Failed to send deployment completion telemetry (non-fatal)"
    fi

    echo ""
    log_success "Deployment completed successfully for $CUSTOMER_ID"
    echo ""
    log_info "Next steps:"
    echo "  1. Verify pods are running: kubectl get pods -n $HELM_NAMESPACE"
    echo "  2. Check application health: kubectl get ingress -n $HELM_NAMESPACE"
    echo "  3. Monitor logs: kubectl logs -f deployment/anysource-backend -n $HELM_NAMESPACE"
    echo "  4. View deployment in Sentry (if telemetry enabled)"

    exit 0
else
    log_error "Helm deployment failed with exit code $HELM_EXIT_CODE"
    echo ""

    # Capture failure details
    ERROR_MESSAGE="helm upgrade failed with exit code $HELM_EXIT_CODE"

    log_info "Capturing deployment failure..."
    if ! bash "$CAPTURE_COMPLETION_SCRIPT" eks "$CUSTOMER_ID" "$INFRA_VERSION" failure "$ERROR_MESSAGE"; then
        log_warning "Failed to send deployment failure telemetry (non-fatal)"
    fi

    echo ""
    log_error "Deployment failed for $CUSTOMER_ID"
    echo ""
    log_info "Troubleshooting steps:"
    echo "  1. Check helm status: helm status $HELM_RELEASE_NAME -n $HELM_NAMESPACE"
    echo "  2. View pod issues: kubectl get pods -n $HELM_NAMESPACE"
    echo "  3. Check events: kubectl get events -n $HELM_NAMESPACE --sort-by=.metadata.creationTimestamp"
    echo "  4. View deployment errors in Sentry (if telemetry enabled)"

    exit $HELM_EXIT_CODE
fi
