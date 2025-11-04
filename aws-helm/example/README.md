# Anysource Helm Chart - Deployment from GitHub Releases

This example demonstrates how to deploy Anysource using the packaged Helm chart from the public [anysource-infra](https://github.com/anysource-AI/anysource-infra) GitHub repository releases.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [AWS Infrastructure Setup with Terraform](#aws-infrastructure-setup-with-terraform)
- [Production Deployment on AWS](#production-deployment-on-aws)
- [Example Configurations](#example-configurations)
- [Upgrading](#upgrading-to-a-new-version)
- [CI/CD Integration](#cicd-integration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Support](#support)

## Overview

This guide demonstrates how to deploy Anysource using the Helm chart from the public [anysource-infra](https://github.com/anysource-AI/anysource-infra) GitHub repository releases.

**For AWS Production deployments:**
1. **Phase 1**: Provision infrastructure using Terraform (EKS, RDS, Redis, IAM roles, Bedrock guardrail)
2. **Phase 2**: Deploy application using Helm with values from Terraform outputs

## Prerequisites

### Production Requirements (AWS)

**⚠️ IMPORTANT: You must provision AWS infrastructure using Terraform before deploying with Helm.**

The Terraform module creates all required AWS resources. See the [AWS Infrastructure Setup](#aws-infrastructure-setup-with-terraform) section below for detailed instructions.

**Required Resources** (created by Terraform):
- EKS cluster with AWS Load Balancer Controller installed
- RDS PostgreSQL database (Aurora Serverless v2)
- ElastiCache Redis cluster  
- ACM SSL certificate for your domain
- IAM role with Bedrock permissions and IRSA trust policy
- Bedrock Guardrail for AI safety
- VPC with proper networking configuration
- AWS Secrets Manager for application secrets

## Quick Start

### 1. Create Your Values File

Download and customize the example values file:

```bash
# Download example-values.yaml from the repository
curl -O https://raw.githubusercontent.com/anysource-AI/anysource-infra/main/aws-helm/example/example-values.yaml

# Edit with your configuration
vi example-values.yaml
```

**Minimum Required Configuration:** See `example-values.yaml` for all required and optional settings.

### 2. Add Helm Repositories

Add required dependencies:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### 3. Deploy

Deploy the chart directly from the GitHub release:

```bash
# Production deployment referencing the release URL
helm upgrade --install anysource \
  https://github.com/anysource-AI/anysource-infra/releases/download/v0.7.0/anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="..." \
  --set backend.secrets.MASTER_SALT="..." \
  --set backend.secrets.AUTH_API_KEY="..." \
  --set externalDatabase.password="..." \
  --timeout 15m \
  --atomic
```

## AWS Infrastructure Setup with Terraform

**Before deploying the Helm chart to AWS, you must provision the required infrastructure using our Terraform module.**

The Terraform module creates all required AWS resources:
- EKS Cluster with node groups and add-ons
- RDS Aurora PostgreSQL Serverless v2
- ElastiCache Redis
- IAM Roles with IRSA (Bedrock permissions)
- Bedrock Guardrail for AI safety
- VPC and networking
- AWS Secrets Manager

**📖 Complete Guide:** Follow the detailed instructions in the [Terraform EKS Module Example](https://github.com/anysource-AI/anysource-infra/tree/main/aws-helm/terraform-eks/example)

After running `terraform apply`, save the outputs - you'll need them for the Helm deployment below.

### Important Terraform Outputs

After running `terraform apply`, save these outputs for your Helm deployment:

| Terraform Output | Use in Helm Values |
|------------------|-------------------|
| `application_service_account_role_arn` | `serviceAccount.annotations.eks.amazonaws.com/role-arn` |
| `bedrock_guardrail_arn` | `backend.env.BEDROCK_GUARDRAIL_ARN` |
| `database_endpoint` | `externalDatabase.host` |
| `redis_endpoint` | `externalRedis.host` |
| `vpc_id` | Used to determine `networkPolicy.vpcCidr` |
| `cluster_name` | For kubectl configuration |

You'll also need:
- Your **ACM certificate ARN** (from AWS Certificate Manager) for `awsCertificate.arn`
- Your **VPC CIDR** (e.g., `10.0.0.0/16`) for `networkPolicy.vpcCidr`

### Complete Terraform to Helm Mapping Reference

Here's a complete reference showing how Terraform configurations and outputs map to Helm values:

| Source | Terraform Variable/Output | Helm Values File Location | Example Value |
|--------|---------------------------|---------------------------|---------------|
| **Terraform Input** | `secret_key` (terraform.tfvars) | `backend.secrets.SECRET_KEY` | Via --set flag |
| **Terraform Input** | `master_salt` (terraform.tfvars) | `backend.secrets.MASTER_SALT` | Via --set flag |
| **Terraform Input** | `auth_api_key` (terraform.tfvars) | `backend.secrets.AUTH_API_KEY` | Via --set flag |
| **Terraform Input** | `database_password` (terraform.tfvars) | `externalDatabase.password` | Via --set flag |
| **Terraform Output** | `database_endpoint` | `externalDatabase.host` | `cluster.xxxxx.us-east-1.rds.amazonaws.com` |
| **Terraform Output** | `redis_endpoint` | `externalRedis.host` | `cluster.xxxxx.cache.amazonaws.com` |
| **Terraform Output** | `bedrock_guardrail_arn` | `backend.env.BEDROCK_GUARDRAIL_ARN` | `arn:aws:bedrock:...` |
| **Terraform Output** | `application_service_account_role_arn` | `serviceAccount.annotations.eks.amazonaws.com/role-arn` | `arn:aws:iam::...` |
| **Terraform Input** | `vpc_cidr` (terraform.tfvars) | `networkPolicy.vpcCidr` | `10.0.0.0/16` |
| **Manual/AWS Console** | ACM Certificate ARN | `awsCertificate.arn` | `arn:aws:acm::...` |

**Important Security Note:** The secrets (SECRET_KEY, MASTER_SALT, AUTH_API_KEY, database_password) must be **identical** in both Terraform and Helm deployments. Store these securely and never commit them to version control.

## Production Deployment on AWS

**Prerequisites**: Complete the [AWS Infrastructure Setup with Terraform](#aws-infrastructure-setup-with-terraform) section above before proceeding.

### Production Values Configuration

Use the `example-values.yaml` file and populate it with your Terraform outputs:

1. **Download the example values file:**
   ```bash
   curl -O https://raw.githubusercontent.com/anysource-AI/anysource-infra/main/aws-helm/example/example-values.yaml
   ```

2. **Edit the file** with your Terraform outputs and configuration:
   - Update `externalDatabase.host` with the `database_endpoint` output
   - Update `externalRedis.host` with the `redis_endpoint` output
   - Update `backend.env.BEDROCK_GUARDRAIL_ARN` with the `bedrock_guardrail_arn` output
   - Update `serviceAccount.annotations.eks.amazonaws.com/role-arn` with the `application_service_account_role_arn` output
   - Update `awsCertificate.arn` with your ACM certificate ARN
   - Update `networkPolicy.vpcCidr` with your VPC CIDR

The `example-values.yaml` file includes detailed comments showing exactly which Terraform outputs to use for each value.

### Deploy to Production

**Prerequisites**: 
- Complete [AWS Infrastructure Setup with Terraform](#aws-infrastructure-setup-with-terraform)
- Have your Terraform outputs ready
- kubectl configured to access your EKS cluster

```bash
# 1. Add Helm repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. Verify kubectl is configured
kubectl get nodes

# 3. Deploy using the release URL
# Use the SAME secret values you provided to Terraform
helm upgrade --install anysource \
  https://github.com/anysource-AI/anysource-infra/releases/download/v0.7.0/anysource-0.7.0.tgz \
  --namespace anysource --create-namespace \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="your-secret-key-32-chars" \
  --set backend.secrets.MASTER_SALT="your-master-salt-32-chars" \
  --set backend.secrets.AUTH_API_KEY="sk_live_your_key" \
  --set externalDatabase.password="your-db-password" \
  --timeout 15m \
  --atomic

# 4. Verify deployment
kubectl get pods -n anysource
kubectl get ingress -n anysource

# 5. Get the ALB DNS name (for DNS configuration)
kubectl get ingress -n anysource -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

**Important Notes:**
- Use the **same secret values** (SECRET_KEY, MASTER_SALT, AUTH_API_KEY, database_password) that you provided to Terraform
- All infrastructure values (RDS endpoint, Redis endpoint, IAM role ARN, etc.) come from Terraform outputs and are specified in your `example-values.yaml` file

## Example Configurations

See [Production Values Configuration](#production-values-configuration) for production deployment with AWS infrastructure.

## Upgrading to a New Version

### 1. Check Release Notes

Review the [release notes](https://github.com/anysource-AI/anysource-infra/releases) for breaking changes.

### 2. Preview Changes (Optional)

Use Helm diff plugin to preview changes:

```bash
# Install diff plugin (if not already installed)
helm plugin install https://github.com/databus23/helm-diff

# Preview the upgrade using the new release URL
helm diff upgrade anysource \
  https://github.com/anysource-AI/anysource-infra/releases/download/v0.8.0/anysource-0.8.0.tgz \
  --namespace anysource \
  -f example-values.yaml
```

### 3. Perform Upgrade

```bash
helm upgrade anysource \
  https://github.com/anysource-AI/anysource-infra/releases/download/v0.8.0/anysource-0.8.0.tgz \
  --namespace anysource \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="..." \
  --set backend.secrets.MASTER_SALT="..." \
  --set backend.secrets.AUTH_API_KEY="..." \
  --set externalDatabase.password="..." \
  --timeout 15m \
  --atomic
```

## CI/CD Integration

### Key Parameters for Helm Deployments

When integrating with CI/CD systems, use environment variables for secrets and version control:

**Chart Configuration:**
```bash
--set-string image.backend.tag="${VERSION}"
--set-string image.frontend.tag="${VERSION}"
--set-string prestart.image.tag="${VERSION}"
--set-string appVersion="${VERSION}"
```

**Secrets (from CI/CD secret vault):**
```bash
--set backend.secrets.SECRET_KEY="${SECRET_KEY}"
--set backend.secrets.MASTER_SALT="${MASTER_SALT}"
--set backend.secrets.AUTH_API_KEY="${AUTH_API_KEY}"
--set backend.secrets.SENTRY_DSN="${SENTRY_DSN}"
--set externalDatabase.password="${DB_PASSWORD}"
```

**Example Deployment Command:**
```bash
helm upgrade --install anysource \
  https://github.com/anysource-AI/anysource-infra/releases/download/v${CHART_VERSION}/anysource-${CHART_VERSION}.tgz \
  --namespace anysource \
  -f example-values.yaml \
  --set backend.secrets.SECRET_KEY="${SECRET_KEY}" \
  --set backend.secrets.MASTER_SALT="${MASTER_SALT}" \
  --set backend.secrets.AUTH_API_KEY="${AUTH_API_KEY}" \
  --set externalDatabase.password="${DB_PASSWORD}" \
  --timeout 15m \
  --atomic
```

## Verification

After deployment, verify the installation:

```bash
# Check pod status
kubectl get pods -n anysource

# Check ingress
kubectl get ingress -n anysource

# Check services
kubectl get svc -n anysource

# View logs
kubectl logs -f deployment/anysource-backend -n anysource
kubectl logs -f deployment/anysource-frontend -n anysource

# Check events if issues occur
kubectl get events -n anysource --sort-by='.lastTimestamp'
```

## Troubleshooting

### Pods Not Starting

```bash
# Check events
kubectl get events -n anysource --sort-by='.lastTimestamp'

# Check pod details
kubectl describe pod <pod-name> -n anysource

# Check logs
kubectl logs <pod-name> -n anysource
```

### Database Connection Issues

```bash
# Test database connectivity
kubectl run -it --rm debug --image=postgres:16 --restart=Never -n anysource -- \
  psql -h your-rds-endpoint -U postgres -d postgres
```

### Dependency Update Issues

If Helm complains about missing dependencies, verify the chart package is complete:

```bash
# View chart contents and values schema
helm show values https://github.com/anysource-AI/anysource-infra/releases/download/v0.7.0/anysource-0.7.0.tgz > chart-defaults.yaml
# Compare with your values file
```

## Best Practices

### Version Management
- Pin specific chart versions in production (avoid `latest`)
- Test upgrades in staging before production
- Document which versions are deployed in each environment

### Secret Management
- Never commit secrets to git
- Use `--set` flags or external secret managers (AWS Secrets Manager, HashiCorp Vault)
- Rotate secrets regularly

### Configuration Management
- Keep environment-specific values files in version control (without secrets)
- Use git to track configuration changes
- Review diffs with `helm diff` before deploying

### Deployment Safety
- Always use `--atomic` flag in production (auto-rollback on failure)
- Preview changes with `helm diff` before deploying
- Have a rollback plan ready
- Monitor deployments closely

### Resource Planning
- Review and adjust resource requests/limits based on actual usage
- Enable horizontal pod autoscaling for production
- Monitor database and Redis performance
- Regular backups of RDS and important data

## Support

- **Documentation**: See the [complete chart documentation](https://github.com/anysource-AI/anysource-infra)
- **Terraform Module**: See the [EKS Terraform Module](https://github.com/anysource-AI/anysource-infra/tree/main/aws-helm/terraform-eks)
- **Issues**: Report issues at [GitHub Issues](https://github.com/anysource-AI/anysource-infra/issues)
- **Support**: Contact engineering@anysource.com
- **Releases**: View all releases and changelog at [GitHub Releases](https://github.com/anysource-AI/anysource-infra/releases)
