# Anysource Kubernetes Helm Chart

Production-ready Helm chart for deploying Anysource on Kubernetes. Supports multiple deployment patterns from development to enterprise production environments.

## Key Features

- **Multi-Environment Support**: Development (embedded databases) to production (external AWS services)
- **Security**: Network policies, pod security contexts, secret management
- **Scalability**: Horizontal Pod Autoscaling (HPA) with CPU/memory metrics
- **Monitoring**: Prometheus integration with ServiceMonitor
- **High Availability**: Anti-affinity rules, disruption budgets, rolling updates
- **Flexibility**: Support for nginx ingress, ALB, Istio service mesh

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
- `auth_domain` - The domain of the Auth tenant for the application (Anysource support will provide this)
- `auth_client_id` - The client ID of the Auth application (Anysource support will provide this)

#### Secret (sensitive configuration)

- `SECRET_KEY` - JWT secret key for authentication
- `MASTER_SALT` - Master salt for encryption

These can be configured in your values file:

```yaml
global:
  domain: "mcp.dev.anysource.com"
  auth_domain: "your-tenant.us.auth0.com"
  auth_client_id: "your-auth-client-id"
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

### Installation Pattern

Use consistent naming and namespace management:

```bash
# Development
helm upgrade --install anysource . \
  --namespace anysource-dev \
  --create-namespace \
  -f values-dev.yaml

# Production  
helm upgrade --install anysource-production . \
  --namespace anysource-production \
  --create-namespace \
  -f values-<environment>.yaml
```

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
helm upgrade --install anysource . \
  --namespace anysource-dev --create-namespace \
  -f values-dev.yaml
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
helm upgrade --install anysource-production . \
  --namespace anysource-production --create-namespace \
  -f values-aws-prod.yaml \
  --wait --timeout=10m
```

## Configuration

### Values Files

- **`values.yaml`** - Default configuration with embedded databases
- **`values-dev.yaml`** - Development environment with local PostgreSQL and Redis
- **`values-aws-prod.yaml`** - AWS production: ALB, ACM, external RDS/ElastiCache, secrets
- **`values-local.yaml`** - Local development configuration
- **`values-prod.yaml`** - Generic production configuration  

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

**In-Cluster PostgreSQL HA (Optional):**

Use Bitnami PostgreSQL in replication mode to run HA PostgreSQL inside the cluster. This is suitable for non-AWS or smaller production setups where a managed database is not available. For AWS production, we still recommend external RDS/Aurora.

```yaml
postgresql:
  enabled: true
  fullnameOverride: "postgresql"

  # Enable HA mode
  architecture: replication

  auth:
    postgresPassword: "CHANGE-ME"
    username: "postgres"
    password: "CHANGE-ME"
    database: "postgres"
    replicationPassword: "CHANGE-REPL-PASSWORD"

  primary:
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    persistence:
      enabled: true
      size: 10Gi
      storageClass: ebs-gp3

  readReplicas:
    replicaCount: 1
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 400m
        memory: 1Gi
    persistence:
      enabled: true
      size: 10Gi
      storageClass: ebs-gp3
```

Notes:

- When `architecture: replication` is enabled, the application will automatically connect to the primary service name `postgresql-primary` (resolved by the chart helpers). In standalone mode, it connects to `postgresql`.
- Read replicas provide redundancy; the application writes to the primary. If you need read/write split, additional application-level routing is required.
- For AWS EKS production, prefer `externalDatabase` (RDS/Aurora) for managed HA, backups, and maintenance.

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

#### HTTPS Redirect Configuration

The chart automatically manages HTTP to HTTPS redirects based on your certificate configuration:

- **When using cert-manager**: HTTP redirects are **disabled** to allow ACME HTTP-01 challenges
- **When using ACM certificates**: HTTP redirects are **enabled** to force HTTPS traffic
- **Manual control**: Use the `ingress.forceHttps` setting to override automatic behavior

**Automatic Behavior:**
```yaml
# cert-manager enabled → no redirects (allows HTTP-01 challenges)
certManager:
  enabled: true
ingress:
  forceHttps: false  # Automatically applied

# cert-manager disabled → redirects enabled
certManager:
  enabled: false
ingress:
  forceHttps: true   # Automatically applied
```

**Manual Override:**
```yaml
# Force redirects even with cert-manager (not recommended)
certManager:
  enabled: true
ingress:
  forceHttps: true   # Manual override

# Disable redirects even without cert-manager
certManager:
  enabled: false
ingress:
  forceHttps: false  # Manual override
```

The redirect uses the ALB annotation: `alb.ingress.kubernetes.io/redirect-to-https`

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
# Enable HTTPS redirects (automatic when cert-manager is disabled)
ingress:
  enabled: true
  className: "alb"
  forceHttps: true  # Optional: explicitly enable redirects
  tls:
    enabled: false # ACM handles TLS termination
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
# Configure ALB Ingress (HTTPS redirects automatically enabled)
ingress:
  enabled: true
  className: "alb"
  forceHttps: true  # Optional: explicitly enable redirects
  tls:
    enabled: false # ACM handles TLS termination
```

**Istio Service Mesh (For clusters with existing Istio installation):**

The chart supports Istio for advanced traffic management. When Istio is enabled, it automatically disables the standard Kubernetes ingress to prevent conflicts.

```yaml
# Disable standard ingress
ingress:
  enabled: false

# Enable Istio resources (optional)
istio:
  enabled: true  # Set to true to create Istio Gateway and VirtualService
  tlsSecretName: "anysource-tls"
  gateway:
    name: anysource-gateway
    selector:
      istio: ingressgateway
    servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
          - "*"
      - port:
          number: 443
          name: https
          protocol: HTTPS
        tls:
          mode: SIMPLE
          credentialName: anysource-tls
        hosts:
          - "*"
  
  virtualService:
    name: anysource-vs
    hosts:
      - "*"
    gateways:
      - anysource-gateway
    http:
      - match:
          - uri:
              prefix: "/api/"
        route:
          - destination:
              host: anysource-backend
              port:
                number: 8000
      - match:
          - uri:
              prefix: "/"
        route:
          - destination:
              host: anysource-frontend
              port:
                number: 80
```

**Prerequisites for Istio:**

1. Istio must be installed in your cluster
2. Istio ingress gateway must be deployed and labeled with `istio: ingressgateway`
3. Cert-manager should be enabled for TLS certificate management
4. AWS ACM certificates are not supported with Istio (use cert-manager instead)

**Deploy with Istio:**

```bash
# Option 1: Use existing Istio resources (recommended)
# Just disable ingress and ensure service names match
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values-istio-cluster.yaml

# Option 2: Create Istio resources from the chart
# Set istio.enabled: true in your values file
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values-istio-cluster.yaml \
  --set istio.enabled=true
```

**Istio Benefits:**

- Advanced traffic routing and load balancing
- Circuit breaking and fault injection
- Detailed metrics and tracing
- mTLS between services
- Canary deployments and A/B testing
- Rate limiting and retry policies

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
helm upgrade --install anysource . \
  --namespace anysource-dev --create-namespace \
  -f values-dev.yaml
```

### Upgrade

```bash
helm upgrade anysource . \
  --namespace anysource-dev \
  -f values-dev.yaml
```

### Uninstall

```bash
helm uninstall anysource -n anysource-dev

# Optionally remove the namespace and all resources (including PVCs)
kubectl delete namespace anysource-dev
```

### Test

```bash
helm test anysource
```

### Debug

```bash
helm template anysource . -f values-dev.yaml --debug
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n anysource
kubectl describe pod <pod-name> -n anysource
```

### View Logs

```bash
kubectl logs -f deployment/<backend-name-from-values> -n anysource
kubectl logs -f deployment/<frontend-name-from-values> -n anysource
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
kubectl describe hpa <backend-name-from-values>-hpa -n anysource
kubectl describe hpa <frontend-name-from-values>-hpa -n anysource
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
