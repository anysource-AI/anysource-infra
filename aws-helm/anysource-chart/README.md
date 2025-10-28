# Anysource Kubernetes Helm Chart

Production-ready Helm chart for deploying Anysource on Kubernetes with support for AWS production environments.

## Bitnami Legacy Images Migration

This chart has been migrated to use **Bitnami Legacy Images** for immediate compatibility:

- **Legacy container images** from `docker.io/bitnamilegacy/`
- **Compatible with existing deployments**
- **Non-root user execution** (user ID 1001)
- **Seccomp profiles** and security contexts
- **Network policies** for additional isolation

### Migration Benefits

- **Immediate compatibility** with existing deployments
- **No breaking changes** to current functionality
- **Maintains security contexts** and best practices
- **Easy rollback** if needed

### Important Notes

- **Legacy images** will not receive future security updates
- **Plan migration** to AWS managed services or Bitnami Secure Images
- **Monitor for security vulnerabilities** in legacy images

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- kubectl configured for your cluster

**For AWS Production:**

- EKS cluster with AWS Load Balancer Controller
- External RDS PostgreSQL and ElastiCache Redis
- AWS ACM certificate
- IAM role with Bedrock permissions and EKS OIDC trust policy

## Quick Start

### 1. Add Required Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### 2. Configure Values

Copy and customize the example values file:

```bash
cp values.example.yaml values-<environment>.yaml
# Edit values-<environment>.yaml with your specific configuration
```

### 3. Deploy Anysource

```bash
# With embedded databases
helm upgrade --install anysource . \
  --namespace anysource-dev --create-namespace \
  -f values-local.yaml

# With external AWS services
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values.example.yaml
```

## Configuration

Copy `values.example.yaml` to create your environment-specific values file:

```bash
cp values.example.yaml values-<environment>.yaml
```

For a complete list of all available configuration options, see [CHART-DOCS.md](./CHART-DOCS.md).

### Required Configuration

Set these values in your values file:

```yaml
global:
  domain: "your-domain.com"
  auth_client_id: "your-auth-client-id"
  # OAuth Broker URL (optional, for OAuth flow handling)
  oauth_broker_url: "https://oauth.staging.runlayer.com"
  # Version URL endpoint (optional, defaults to Anysource version endpoint)
  version_url: "https://anysource-version.s3.amazonaws.com/version.json"

backend:
  secrets:
    SECRET_KEY: "your-jwt-secret-key-minimum-32-characters"
    MASTER_SALT: "your-master-salt-minimum-32-characters"
    AUTH_API_KEY: "your-auth-api-key"
```

### Database Configuration

**Embedded PostgreSQL:**

```yaml
postgresql:
  enabled: true
```

**External RDS:**

```yaml
postgresql:
  enabled: false
externalDatabase:
  enabled: true
  host: "your-rds-endpoint"
  existingSecret: "anysource-db-secret"
```

### Certificate Management

**AWS ACM (Recommended for AWS):**

```yaml
awsCertificate:
  enabled: true
  arn: "arn:aws:acm:region:account:certificate/cert-id"
certManager:
  enabled: false
```

**Let's Encrypt (Non-AWS Deployment):**

```yaml
certManager:
  enabled: true
  issuer:
    email: "your-email@example.com"
awsCertificate:
  enabled: false
```

## AWS IAM Role Configuration

For AWS production deployments, you'll need to create an IAM role with the following configuration:

### Required Permissions

The role must have the following Bedrock permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:CreateGuardrail",
    "bedrock:GetGuardrail",
    "bedrock:ListGuardrails",
    "bedrock:UpdateGuardrail",
    "bedrock:DeleteGuardrail",
    "bedrock:ApplyGuardrail",
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream"
  ],
  "Resource": "*"
}
```

### Trust Policy

The role must have this trust policy to allow EKS service account access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<aws_account_id>:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/oidc_id"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/oidc_id:sub": "system:serviceaccount:<anysource_namespace>:anysource",
          "oidc.eks.us-east-1.amazonaws.com/id/oidc_id:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Replace:

- `<aws_account_id>` with your AWS account ID
- `<oidc_id>` with your EKS cluster's OIDC provider ID
- `<anysource_namespace>` with your deployment namespace

### Configure in Values

Set the role ARN in your values file:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::<aws_account_id>:role/your-anysource-role"
```

## Helm Chart Packaging (Internal Use)

### Creating a Helm Chart Package

To create a distributable Helm chart package (.tgz file):

#### 1. Update Chart Version

**IMPORTANT**: Always bump the chart version in `Chart.yaml` before packaging:

```yaml
# Chart.yaml
version: 0.7.0 # Increment this (e.g., to 0.7.1 or 0.8.0)
appVersion: "1.3.0" # Update if application version changed
```

**Version Guidelines:**

- **Chart version** (`version`): Increment when chart templates, values, or dependencies change
  - Patch (0.7.0 → 0.7.1): Bug fixes, minor template changes
  - Minor (0.7.0 → 0.8.0): New features, new configuration options
  - Major (0.7.0 → 1.0.0): Breaking changes, incompatible upgrades
- **App version** (`appVersion`): Update when backend/frontend Docker image versions change

#### 2. Update Dependencies

**IMPORTANT**: Always update dependencies before packaging:

```bash
# Update all chart dependencies (PostgreSQL, Redis, cert-manager)
helm dependency update

# This will:
# - Download the latest versions of dependencies specified in Chart.yaml
# - Create/update Chart.lock with exact versions
# - Save dependency charts to charts/ directory
```

#### 3. Package the Chart

```bash
# Create the .tgz package
helm package .

# Output: anysource-0.7.0.tgz (version from Chart.yaml)
```

#### 4. Verify the Package

```bash
# Test the package before distribution
helm template anysource ./anysource-0.7.0.tgz \
  -f values.example.yaml \
  --validate

# Or test installation in a test namespace
helm upgrade --install anysource-test ./anysource-0.7.0.tgz \
  --namespace test --create-namespace \
  -f values-local.yaml \
  --dry-run
```

### Complete Packaging Workflow

```bash
# 1. Navigate to chart directory
cd infra/aws-helm/anysource-chart

# 2. Update Chart.yaml version
# Edit Chart.yaml and increment version

# 3. Update dependencies
helm dependency update

# 4. Package the chart
helm package .

# 5. Verify the package
helm template anysource ./anysource-0.7.0.tgz -f values.example.yaml --validate

# 6. Distribute the package
# - Upload to S3, artifact repository, or Helm repository
# - Share with deployment teams
# - Archive for version control
```

### When to Create a Package

- Before deploying to staging or production environments
- After making changes to chart templates or values
- When releasing a new version for customer deployments
- For archiving and maintaining deployment history
- When dependencies have been updated

### Using Packaged Charts

Once packaged, deploy using the .tgz file:

```bash
# Deploy from local package
helm upgrade --install anysource ./anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f values-<environment>.yaml

# Deploy from remote URL
helm upgrade --install anysource https://releases.example.com/anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f values-<environment>.yaml
```

## Commands

### Install/Upgrade

<Tabs>
  <Tab title="Using Chart Directory">
```bash
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values-<environment>.yaml
```
  </Tab>

  <Tab title="Using Packaged Chart">
```bash
helm upgrade --install anysource ./anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f values-<environment>.yaml
```
  </Tab>
</Tabs>

### Uninstall

```bash
helm uninstall anysource -n anysource
kubectl delete namespace anysource
```

### Debug

```bash
# Debug with chart directory
helm template anysource . -f values-<environment>.yaml --debug --validate=false

# Debug with packaged chart
helm template anysource ./anysource-0.7.0.tgz \
  -f values-<environment>.yaml --debug --validate=false
```

## Troubleshooting

### Check Status

```bash
kubectl get pods -n anysource
kubectl get ingress -n anysource
kubectl get hpa -n anysource
```

### View Logs

```bash
kubectl logs -f deployment/anysource-backend -n anysource
kubectl logs -f deployment/anysource-frontend -n anysource
```

### Check Events

```bash
kubectl get events -n anysource --sort-by='.lastTimestamp'
```

## Support

For issues and questions, contact the Anysource team at team@anysource.dev
