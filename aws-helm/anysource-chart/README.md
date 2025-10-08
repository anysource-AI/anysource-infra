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

## Commands

### Install/Upgrade
```bash
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values-<environment>.yaml
```

### Uninstall
```bash
helm uninstall anysource -n anysource
kubectl delete namespace anysource
```

### Debug
```bash
helm template anysource . -f values-<environment>.yaml --debug --validate=false
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
