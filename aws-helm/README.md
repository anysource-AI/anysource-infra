# Anysource Kubernetes Deployment

This directory contains Kubernetes Helm charts for deploying Anysource on Kubernetes clusters, and a Terraform module for AWS EKS cluster provisioning.

## Documentation Structure

| Document                                                                               | Purpose                                                   | Audience                 |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------------------------ |
| **This README**                                                                        | Overview and quick start                                  | Everyone                 |
| **[anysource-chart/README.md](./anysource-chart/README.md)**                           | Detailed Helm chart documentation, packaging instructions | Developers, DevOps       |
| **[anysource-chart/CHART-DOCS.md](./anysource-chart/CHART-DOCS.md)**                   | Complete chart configuration reference                    | DevOps, System Admins    |
| **[terraform-eks/README.md](./terraform-eks/README.md)**                               | EKS cluster provisioning and infrastructure               | Infrastructure Engineers |
| **[aws-load-balancer-controller/README.md](./aws-load-balancer-controller/README.md)** | AWS Load Balancer Controller setup                        | DevOps                   |

## Features

- AWS EKS with ALB ingress and ACM certificates
- External RDS and ElastiCache integration
- Secure secret management via Kubernetes Secrets
- Advanced network policies and pod security
- Horizontal Pod Autoscaling (HPA)
- Prometheus monitoring and ServiceMonitor

## Directory Structure

```
aws-helm/
├── anysource-chart/                    # Main Helm chart
│   ├── Chart.yaml                      # Chart metadata and dependencies
│   ├── values.yaml                     # Default values
│   ├── values-dev.yaml                 # Development environment values
│   ├── values-aws-prod.yaml            # AWS production values (external RDS/ElastiCache, ACM, ALB, secrets)
│   ├── README.md                       # Detailed chart documentation
│   ├── charts/                         # Chart dependencies
│   └── templates/                      # Kubernetes templates
│       ├── _helpers.tpl                # Template helpers
│       ├── serviceaccount.yaml         # Service account
│       ├── secrets.yaml                # Secrets management
│       ├── configmap.yaml              # Configuration
│       ├── backend-deployment.yaml     # Backend deployment
│       ├── frontend-deployment.yaml    # Frontend deployment
│       ├── services.yaml               # Services
│       ├── ingress.yaml                # Ingress configuration
│       ├── hpa.yaml                    # Horizontal Pod Autoscaler
│       ├── certificates.yaml           # TLS certificates
│       ├── networkpolicies.yaml        # Network security policies
│       ├── poddisruptionbudget.yaml    # High availability
│       ├── storageclass.yaml           # Storage class configuration
│       └── tests/                      # Helm tests
└── terraform-eks/                      # EKS cluster provisioning
    ├── eks.tf                          # EKS cluster configuration
    ├── variables.tf                    # Terraform variables
    ├── outputs.tf                      # Terraform outputs
    ├── terraform.tfvars.example        # Example configuration
    └── README.md                       # EKS Terraform documentation
```

## Quick Start

### Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- kubectl configured for your cluster

### Development Deployment

```bash
# Add required Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Deploy with development values
cd anysource-chart
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values-dev.yaml
```

## Optional: EKS Cluster Provisioning

If you don't have an existing Kubernetes cluster, you can use the included Terraform module to provision an AWS EKS cluster.

**For complete EKS provisioning documentation, see [terraform-eks/README.md](./terraform-eks/README.md).**

### Quick Start

```bash
# Navigate to the Terraform EKS module
cd terraform-eks

# Copy and edit the configuration
cp terraform.tfvars.example terraform.tfvars

# Initialize and apply Terraform
terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

### Key Features

- **3 Deployment Modes**: Full Stack, Existing VPC, or Existing EKS
- **Managed Infrastructure**: EKS, RDS, ElastiCache, VPC, IAM roles
- **Security**: KMS encryption, IRSA, private endpoints
- **Essential Add-ons**: Pre-configured with CoreDNS, VPC CNI, EBS CSI driver, CloudWatch
- **Production Ready**: Auto-scaling, monitoring, multi-AZ support

See the [Terraform EKS README](./terraform-eks/README.md) for:

- Detailed deployment modes and configuration options
- Using existing VPC or EKS clusters
- Security best practices and monitoring setup
- Troubleshooting and cost optimization

### Production Deployment (AWS)

```bash
# Create required secrets for RDS and ElastiCache
kubectl create secret generic anysource-db-secret \
  --from-literal=password="your-db-password" \
  --namespace anysource
kubectl create secret generic anysource-redis-secret \
  --from-literal=password="your-redis-password" \
  --namespace anysource

# Deploy to production with AWS values
cd anysource-chart
helm upgrade --install anysource . \
  --namespace anysource --create-namespace \
  -f values-aws-prod.yaml \
  --wait --timeout=10m
```

## Configuration Options

For detailed configuration options, values files, and examples, see:

- **Helm Chart Configuration**: [anysource-chart/README.md](./anysource-chart/README.md#configuration)
- **Chart Documentation**: [anysource-chart/CHART-DOCS.md](./anysource-chart/CHART-DOCS.md)

**Quick Overview:**

| Environment | Values File            | Description                                   |
| ----------- | ---------------------- | --------------------------------------------- |
| Development | `values-dev.yaml`      | Local PostgreSQL and Redis, minimal resources |
| Production  | `values-aws-prod.yaml` | AWS RDS and ElastiCache, production resources |

## Key Features

For detailed information on each feature, see [anysource-chart/README.md](./anysource-chart/README.md).

### Security

- Container security (non-root, read-only filesystem, dropped capabilities)
- Network policies and service isolation
- Kubernetes secrets with AWS Secrets Manager integration
- RBAC and AWS IAM integration (IRSA)

### Monitoring & Observability

- Health checks (liveness, readiness, startup probes)
- Prometheus integration with ServiceMonitor
- Structured logging with JSON output

### High Availability

- Pod anti-affinity rules and disruption budgets
- Horizontal Pod Autoscaling (HPA)
- Zero-downtime rolling updates

## Deployment Environments

The Helm chart supports multiple deployment patterns. See [anysource-chart/README.md](./anysource-chart/README.md) for detailed configuration examples.

| Environment     | Infrastructure            | Scaling            | Best For             |
| --------------- | ------------------------- | ------------------ | -------------------- |
| **Development** | Embedded PostgreSQL/Redis | Fixed replicas     | Local testing        |
| **Production**  | AWS RDS/ElastiCache       | Auto-scaling (HPA) | Production workloads |

## Helm Chart Packaging (Internal)

For detailed instructions on packaging the Helm chart for distribution, see [anysource-chart/README.md](./anysource-chart/README.md#helm-chart-packaging-internal-use).

**Quick Reference:**

```bash
cd anysource-chart

# 1. Update Chart.yaml version
# 2. Update dependencies
helm dependency update

# 3. Package
helm package .

# 4. Verify
helm template anysource ./anysource-0.7.0.tgz -f values-aws-prod.yaml --validate
```

**Important:**

- Always bump chart version in `Chart.yaml` before packaging
- Always run `helm dependency update` to ensure dependencies are current
- See the chart README for complete version guidelines and best practices

## Common Commands

### Deployment

```bash
# Install development (from directory)
cd anysource-chart
helm upgrade --install anysource . -f values-dev.yaml --namespace anysource --create-namespace

# Install production (from directory)
helm upgrade --install anysource . -f values-aws-prod.yaml --namespace anysource --create-namespace

# Install from packaged chart (recommended for production)
helm upgrade --install anysource ./anysource-0.7.0.tgz \
  -f values-aws-prod.yaml --namespace anysource --create-namespace

# Upgrade existing deployment
helm upgrade anysource . -f values-dev.yaml --namespace anysource

# Uninstall
helm uninstall anysource --namespace anysource
```

### Monitoring

```bash
# Check status
kubectl get pods,svc,ingress -n anysource

# View logs
kubectl logs -f deployment/anysource-backend -n anysource

# Check HPA
kubectl get hpa -n anysource

# Test connection
helm test anysource -n anysource
```

### Troubleshooting

```bash
# Describe resources
kubectl describe pod <pod-name> -n anysource

# Check events
kubectl get events -n anysource --sort-by=.metadata.creationTimestamp

# Debug deployment
cd anysource-chart
helm template anysource . -f values-dev.yaml --debug

# Port forward for local access
kubectl port-forward svc/anysource-frontend 8080:80 -n anysource
```

## Architecture Overview

This deployment uses Kubernetes orchestration with AWS managed services for production.

### Deployment Order

When starting from scratch on AWS:

1. **Infrastructure** - Provision EKS, RDS, ElastiCache (see [terraform-eks/README.md](./terraform-eks/README.md))
2. **Application** - Deploy with Helm chart (see [anysource-chart/README.md](./anysource-chart/README.md))

The Terraform EKS module handles infrastructure provisioning, while the Helm chart manages application deployment.

## Related Documentation

### Internal Documentation

- **[Helm Chart README](./anysource-chart/README.md)** - Detailed chart documentation and packaging guide
- **[Chart Configuration](./anysource-chart/CHART-DOCS.md)** - Complete values reference
- **[Terraform EKS Module](./terraform-eks/README.md)** - Infrastructure provisioning guide
- **[AWS Load Balancer Controller](./aws-load-balancer-controller/README.md)** - ALB controller setup

### User-Facing Documentation

For customer-facing deployment guides, see:

- **User Deployment Docs**: `/docs/deployment/helm.mdx` - External Helm deployment guide
- **EKS Terraform Docs**: `/docs/deployment/eks-terraform.mdx` - External EKS guide

### Internal Operations

For internal deployment procedures, see:

- **Internal EKS Deployments**: `/infra-internal/eks/README.md` - Internal environment configurations

## Support

- **Issues**: Report issues to the Anysource team
- **Contact**: team@anysource.dev

## Contributing

1. Update the appropriate README when making changes:
   - Chart changes → Update `anysource-chart/README.md`
   - Terraform changes → Update `terraform-eks/README.md`
   - Overview changes → Update this README
2. Test changes locally with development values
3. Validate with `helm template` and `helm lint`
4. Test on staging environment before production
5. Follow semantic versioning for chart versions
