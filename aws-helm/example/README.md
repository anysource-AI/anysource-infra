# Runlayer Helm Chart - Deployment Guide

Deploy Runlayer using the packaged Helm chart from GitHub releases.

**AWS Production:** Provision infrastructure with Terraform first, then deploy with Helm using Terraform outputs.

## Prerequisites

**⚠️ AWS Production:** Provision infrastructure with Terraform before deploying Helm.

See [Terraform EKS Module Example](https://github.com/anysource-AI/runlayer-infra/tree/main/aws-helm/terraform-eks/example) for infrastructure setup.

## Quick Start

```bash
# 1. Download example values
curl -O https://raw.githubusercontent.com/anysource-AI/runlayer-infra/main/aws-helm/example/example-values.yaml

# 2. Add Helm repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 3. Deploy
helm upgrade --install anysource \
  https://github.com/anysource-AI/runlayer-infra/releases/download/v0.7.0/anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="..." \
  --set backend.secrets.MASTER_SALT="..." \
  --set backend.secrets.AUTH_API_KEY="..." \
  --set externalDatabase.password="..." \
  --timeout 15m \
  --atomic
```

## Terraform to Helm Mapping

| Terraform Output/Input                 | Helm Values Location                                    |
| -------------------------------------- | ------------------------------------------------------- |
| `database_endpoint` (output)           | `externalDatabase.host`                                 |
| `redis_endpoint` (output)              | `externalRedis.host`                                    |
| `bedrock_guardrail_arn` (output)       | `backend.env.BEDROCK_GUARDRAIL_ARN`                     |
| `application_service_account_role_arn` | `serviceAccount.annotations.eks.amazonaws.com/role-arn` |
| `vpc_cidr` (input)                     | `networkPolicy.vpcCidr`                                 |
| ACM Certificate ARN (manual)           | `awsCertificate.arn`                                    |
| `secret_key` (input)                   | `backend.secrets.SECRET_KEY` (--set flag)               |
| `master_salt` (input)                  | `backend.secrets.MASTER_SALT` (--set flag)              |
| `auth_api_key` (input)                 | `backend.secrets.AUTH_API_KEY` (--set flag)             |
| `database_password` (input)            | `externalDatabase.password` (--set flag)                |

**Security:** Secrets must be identical in Terraform and Helm. Never commit to version control.

## Production Deployment

```bash
# 1. Configure kubectl
kubectl get nodes

# 2. Deploy (use same secrets as Terraform)
helm upgrade --install anysource \
  https://github.com/anysource-AI/runlayer-infra/releases/download/v0.7.0/anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="your-secret-key-32-chars" \
  --set backend.secrets.MASTER_SALT="your-master-salt-32-chars" \
  --set backend.secrets.AUTH_API_KEY="sk_live_your_key" \
  --set externalDatabase.password="your-db-password" \
  --timeout 15m \
  --atomic

# 3. Verify
kubectl get pods -n anysource
kubectl get ingress -n anysource
```

## Upgrading

```bash
# Preview changes (optional)
helm plugin install https://github.com/databus23/helm-diff
helm diff upgrade anysource \
  https://github.com/anysource-AI/runlayer-infra/releases/download/v0.8.0/anysource-0.8.0.tgz \
  -f example-values.yaml

# Upgrade
helm upgrade anysource \
  https://github.com/anysource-AI/runlayer-infra/releases/download/v0.8.0/anysource-0.8.0.tgz \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="..." \
  --set backend.secrets.MASTER_SALT="..." \
  --set backend.secrets.AUTH_API_KEY="..." \
  --set externalDatabase.password="..." \
  --timeout 15m \
  --atomic
```

## CI/CD Integration

```bash
helm upgrade --install anysource \
  https://github.com/anysource-AI/runlayer-infra/releases/download/v${CHART_VERSION}/anysource-${CHART_VERSION}.tgz \
  --namespace anysource \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="${SECRET_KEY}" \
  --set backend.secrets.MASTER_SALT="${MASTER_SALT}" \
  --set backend.secrets.AUTH_API_KEY="${AUTH_API_KEY}" \
  --set externalDatabase.password="${DB_PASSWORD}" \
  --set-string image.backend.tag="${VERSION}" \
  --set-string image.frontend.tag="${VERSION}" \
  --timeout 15m \
  --atomic
```

## Troubleshooting

```bash
# Check pods
kubectl get pods -n anysource
kubectl describe pod <pod-name> -n anysource
kubectl logs <pod-name> -n anysource

# Test database
kubectl run -it --rm debug --image=postgres:16 --restart=Never -n anysource -- \
  psql -h your-rds-endpoint -U postgres -d postgres

# Check events
kubectl get events -n anysource --sort-by='.lastTimestamp'
```
