# Anysource Kubernetes Helm Chart

This Helm chart deploys the Anysource application on Kubernetes with support for multiple environments and configurations, including:

- AWS EKS with ALB ingress and ACM certificates (production)
- External RDS and ElastiCache integration (production)
- Secure secret management via Kubernetes Secrets (see `existingSecret` and `existingSecretPasswordKey`)
- Advanced network policies and pod security
- Horizontal Pod Autoscaling (HPA)
- Prometheus monitoring and ServiceMonitor

## Overview

The chart includes:

- **Backend** (FastAPI) deployment with database prestart init container
- **Frontend** (React/Vite) deployment
- **PostgreSQL** (optional, for development)
- **Redis** (optional, for development)
- **Nginx Ingress** or **AWS ALB** support
- **Cert-manager** or **AWS ACM** for TLS certificates
- **Horizontal Pod Autoscaling (HPA)**
- **Network Policies** for security
- **Prometheus monitoring** support
- **Security best practices** implementation

## Configuration

### Environment Variables

The chart manages configuration through globals, environment variables and secrets:

#### Globals

- `domain` - The domain name for the application
- `auth0_domain` - The domain of the Auth0 tenant for the application (Anysource support will provide this)
- `auth0_client_id` - The client ID of the Auth0 application (Anysource support will provide this)

#### Secret (sensitive configuration)

- `SECRET_KEY` - JWT secret key for authentication
- `MASTER_SALT` - Master salt for encryption

These can be configured in your values file:

```yaml
global:
  domain: "mcp.dev.anysource.com"
  auth0_domain: "your-tenant.us.auth0.com"
  auth0_client_id: "your-auth0-client-id"
# [...]
backend:
  secrets:
    SECRET_KEY: "your-jwt-secret-key-minimum-32-characters"
    MASTER_SALT: "your-master-salt-minimum-32-characters"
```

**Security Note**: Always use secure, randomly generated values for secrets in production environments.

## Prerequisites

### For Development Environment:

- Kubernetes 1.19+
- Helm 3.8+
- kubectl configured for your cluster
- nginx-ingress-controller (if using nginx ingress)

### For AWS Production Environment:

- EKS cluster
- AWS Load Balancer Controller
- External RDS PostgreSQL database
- External ElastiCache Redis
- AWS ACM certificate
- Appropriate IAM roles and policies

## Quick Start

### Development Deployment

```bash
# Add Bitnami and Jetstack repositories for dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager (if using cert-manager)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.crds.yaml
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.1

# Install nginx ingress controller (if using nginx)
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Deploy Anysource with development values
helm install anysource ./anysource-chart -f values-dev.yaml
```

### AWS Production Deployment

```bash
# Create secrets for external database and Redis
kubectl create secret generic anysource-db-secret \
  --from-literal=password="your-db-password" \
  --namespace anysource
kubectl create secret generic anysource-redis-secret \
  --from-literal=password="your-redis-password" \
  --namespace anysource

# Deploy with AWS production values (ALB, ACM, external RDS/ElastiCache, secrets)
helm install anysource ./anysource-chart -f values-aws-prod.yaml --namespace anysource --wait --timeout=10m
```

## Configuration

### Values Files

- **`values.yaml`** - Default configuration with embedded databases
- **`values-dev.yaml`** - Development environment with local PostgreSQL and Redis
- **`values-aws-prod.yaml`** - AWS production: ALB, ACM, external RDS/ElastiCache, secrets

### Key Configuration Options

#### Database Configuration

**Embedded PostgreSQL (Development):**

```yaml
postgresql:
  enabled: true
  auth:
    postgresPassword: "postgres123"
    username: "postgres"
    password: "postgres123"
    database: "postgres"
```

**External Database (Production):**

```yaml
postgresql:
  enabled: false
externalDatabase:
  enabled: true
  host: "your-rds-endpoint"
  port: 5432
  database: "postgres"
  username: "postgres"
  existingSecret: "anysource-db-secret"
  existingSecretPasswordKey: "password"
```

#### Redis Configuration

**Embedded Redis (Development):**

```yaml
redis:
  enabled: true
  auth:
    enabled: true
    password: "redis123"
```

**External Redis (Production):**

```yaml
redis:
  enabled: false
externalRedis:
  enabled: true
  host: "your-elasticache-endpoint"
  port: 6379
  existingSecret: "anysource-redis-secret"
  existingSecretPasswordKey: "password"
```

#### Storage Class Configuration

The chart includes a configurable storage class for persistent volumes. By default, it creates an optimized `ebs-gp3` storage class for AWS EKS clusters.

**Default Configuration:**

```yaml
storageClass:
  enabled: true
  name: ebs-gp3
  isDefault: true
  provisioner: ebs.csi.aws.com
  volumeBindingMode: WaitForFirstConsumer
  allowVolumeExpansion: true
  reclaimPolicy: Delete
  parameters:
    type: gp3
    encrypted: "true"
  disableGp2Default: true
```

**Key Features:**

- Creates an encrypted gp3 storage class as default
- Automatically disables gp2 as default to prevent conflicts
- Supports volume expansion
- Uses `WaitForFirstConsumer` binding for better availability zone placement
- Configurable IOPS and throughput for performance optimization

**Note:** This storage class requires the AWS EBS CSI driver to be installed and properly configured with IAM permissions in your EKS cluster.

#### TLS Certificate Configuration

You can choose between two TLS certificate management options:

##### Option 1: AWS ACM Certificate (Recommended for AWS environments)

Use this option when deploying to AWS EKS and you have an ACM certificate:

```yaml
# Disable cert-manager
certManager:
  enabled: false
# Enable AWS ACM certificate
awsCertificate:
  enabled: true
  arn: "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
# Configure ALB Ingress (ACM handles TLS termination)
ingress:
  enabled: true
  className: "alb"
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/redirect-to-https: '{"Type": "redirect", "RedirectConfig": {"Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
  tls:
    enabled: false # ACM handles TLS, so disable ingress TLS section
```

**Prerequisites for AWS ACM:**

1. Valid ACM certificate in the same region as your EKS cluster
2. Certificate must be validated (DNS or email validation)
3. Domain name in the certificate must match your `global.domain` value
4. AWS Load Balancer Controller must be installed and configured

**Steps to use AWS ACM:**

1. Create or import a certificate in AWS Certificate Manager
2. Validate the certificate using DNS or email validation
3. Copy the certificate ARN from the AWS Console
4. Set `awsCertificate.enabled: true` and provide the ARN
5. Set `certManager.enabled: false`
6. Set `ingress.tls.enabled: false`

##### Option 2: Cert-manager (For development or non-AWS environments)

Use this option for development or when ACM is not available:

```yaml
# Enable cert-manager
certManager:
  enabled: true
  issuer:
    name: letsencrypt-prod
    email: "admin@yourcompany.com"
    server: https://acme-v02.api.letsencrypt.org/directory

# Disable AWS ACM
awsCertificate:
  enabled: false

# Configure ingress with TLS
ingress:
  enabled: true
  tls:
    enabled: true
    secretName: anysource-tls
```

#### Ingress Configuration

**Nginx Ingress (Development/Non-AWS environments):**

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  tls:
    enabled: true
    secretName: anysource-tls
certManager:
  enabled: true
```

**AWS ALB with ACM (Recommended for AWS production environments):**

```yaml
# AWS ALB with ACM Certificate
awsCertificate:
  enabled: true
  arn: "arn:aws:acm:region:account:certificate/cert-id"
# Disable cert-manager when using ACM
certManager:
  enabled: false
# Configure ALB Ingress
ingress:
  enabled: true
  className: "alb"
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/redirect-to-https: '{"Type": "redirect", "RedirectConfig": {"Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
  tls:
    enabled: false # ACM handles TLS termination
```

#### Resource Configuration

```yaml
backend:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

frontend:
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
```

#### HPA Configuration

```yaml
hpa:
  backend:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

## Security Features

### Pod Security Context

- Runs as non-root user (UID 1000)
- Read-only root filesystem (production)
- Dropped all capabilities
- seccomp profile

### Network Policies

- Restricts pod-to-pod communication
- Allows only necessary traffic flows
- Isolates database and Redis access

### Service Account

- Dedicated service account with minimal permissions
- AWS IAM role integration for EKS

## Monitoring

### Prometheus Integration

- Metrics endpoint at `/metrics`
- ServiceMonitor for automatic discovery
- Custom annotations for scraping

### Health Checks

- Liveness probes with configurable timeouts
- Readiness probes for proper load balancing
- Startup probes for slow-starting containers

## Deployment Commands

### Install

```bash
helm install anysource ./anysource-chart -f values-dev.yaml
```

### Upgrade

```bash
helm upgrade anysource ./anysource-chart -f values-dev.yaml
```

### Uninstall

```bash
helm uninstall anysource
```

### Test

```bash
helm test anysource
```

### Debug

```bash
helm template anysource ./anysource-chart -f values-dev.yaml --debug
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n anysource
kubectl describe pod <pod-name> -n anysource
```

### View Logs

```bash
kubectl logs -f deployment/anysource-backend -n anysource
kubectl logs -f deployment/anysource-frontend -n anysource
```

### Check Database Prestart

```bash
kubectl logs -l app.kubernetes.io/component=backend -c prestart -n anysource
```

### Check Ingress

```bash
kubectl get ingress -n anysource
kubectl describe ingress anysource-ingress -n anysource
```

### Check HPA

```bash
kubectl get hpa -n anysource
kubectl describe hpa anysource-backend-hpa -n anysource
```

## Customization

### Environment Variables

Add custom environment variables in values.yaml:

```yaml
backend:
  env:
    CUSTOM_VAR: "value"
```

### Secrets

Add custom secrets:

```yaml
backend:
  secrets:
    SECRET_KEY: "base64-encoded-value"
```

### Additional Volumes

Mount additional volumes by extending the deployment templates.

## Support

For issues and questions:

- Check the troubleshooting section
- Review Kubernetes events: `kubectl get events -n anysource`
- Contact the Anysource team at team@anysource.dev
