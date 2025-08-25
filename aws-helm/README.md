# Anysource Kubernetes Deployment

This directory contains Kubernetes Helm charts for deploying Anysource on Kubernetes clusters, and a Terraform module for AWS EKS cluster provisioning. The Helm chart supports:

- AWS EKS with ALB ingress and ACM certificates
- External RDS and ElastiCache integration
- Secure secret management via Kubernetes Secrets
- Advanced network policies and pod security
- Horizontal Pod Autoscaling (HPA)
- Prometheus monitoring and ServiceMonitor

## Directory Structure

```
aws-helm/
├── anysource-chart/             # Main Helm chart
│   ├── Chart.yaml               # Chart metadata and dependencies
│   ├── values.yaml              # Default values
│   ├── values-dev.yaml          # Development environment values
│   ├── values-aws-prod.yaml     # AWS production values (external RDS/ElastiCache, ACM, ALB, secrets)
│   ├── README.md                # Detailed chart documentation
│   ├── charts/                  # Chart dependencies
│   └── templates/               # Kubernetes templates
│       ├── _helpers.tpl         # Template helpers
│       ├── serviceaccount.yaml  # Service account
│       ├── secrets.yaml         # Secrets management
│       ├── configmap.yaml       # Configuration
│       ├── backend-deployment.yaml     # Backend deployment
│       ├── frontend-deployment.yaml    # Frontend deployment
│       ├── services.yaml        # Services
│       ├── ingress.yaml         # Ingress configuration
│       ├── hpa.yaml             # Horizontal Pod Autoscaler
│       ├── certificates.yaml    # TLS certificates
│       ├── networkpolicies.yaml # Network security policies
│       ├── poddisruptionbudget.yaml # High availability
│       ├── storageclass.yaml    # Storage class configuration
│       ├── istio-gateway.yaml   # Istio gateway (optional)
│       ├── istio-virtualservice.yaml # Istio virtual service (optional)
│       └── tests/               # Helm tests
└── terraform-eks/               # EKS cluster provisioning
    ├── eks.tf                   # EKS cluster configuration
    ├── variables.tf             # Terraform variables
    ├── outputs.tf               # Terraform outputs
    ├── terraform.tfvars.example # Example configuration
    └── README.md                # EKS Terraform documentation
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

If you don't have an existing Kubernetes cluster, you can use the included Terraform module to provision an AWS EKS cluster. This module supports advanced networking, IRSA, KMS encryption, and flexible node group/add-on configuration. See `terraform-eks/README.md` for details.

### EKS Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Existing VPC with private subnets (and optionally public subnets)

### Create EKS Cluster

```bash
# Navigate to the Terraform EKS module
cd terraform-eks

# Copy and edit the configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS account details and VPC information

# Initialize and apply Terraform
terraform init
terraform plan
terraform apply

# Configure kubectl to use the new cluster
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

### EKS Features

- **Managed Node Groups**: Auto-scaling EKS managed nodes
- **Security**: KMS encryption for Kubernetes secrets
- **IRSA Support**: IAM Roles for Service Accounts enabled
- **Essential Add-ons**: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver
- **Flexible Configuration**: Configurable instance types, scaling, and spot instances
- **Advanced Networking**: Works with existing VPC and subnets, supports private/public subnet tagging
- **Production Security**: Restrict API access, enable private endpoint, whitelist IPs, custom security group rules, encryption

For detailed EKS configuration options, see [terraform-eks/README.md](./terraform-eks/README.md).

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

### Environment Configurations

| Environment | Values File            | Description                                   |
| ----------- | ---------------------- | --------------------------------------------- |
| Development | `values-dev.yaml`      | Local PostgreSQL and Redis, minimal resources |
| Production  | `values-aws-prod.yaml` | AWS RDS and ElastiCache, production resources |

### Infrastructure Options

| Component      | Development         | Production (AWS)                         |
| -------------- | ------------------- | ---------------------------------------- |
| **Database**   | Embedded PostgreSQL | AWS RDS (externalDatabase + secret)      |
| **Cache**      | Embedded Redis      | AWS ElastiCache (externalRedis + secret) |
| **Ingress**    | nginx-ingress       | AWS ALB (with ACM)                       |
| **TLS**        | cert-manager        | AWS ACM                                  |
| **Monitoring** | Optional            | Enabled (Prometheus, ServiceMonitor)     |
| **HPA**        | Disabled            | Enabled                                  |

## Security Features

✅ **Container Security**

- Non-root containers (UID 1000)
- Read-only root filesystem
- Dropped capabilities
- Security contexts
  ✅ **Network Security**
- Network policies
- Service isolation
- Ingress restrictions
  ✅ **Secrets Management**
- Kubernetes secrets (use `existingSecret` and `existingSecretPasswordKey` for AWS)
- External secret integration (AWS Secrets Manager)
- Encrypted storage
  ✅ **RBAC**
- Minimal service accounts
- Principle of least privilege
- AWS IAM integration (IRSA)

## Monitoring & Observability

- **Health Checks**: Liveness, readiness, and startup probes
- **Metrics**: Prometheus integration with ServiceMonitor
- **Logging**: Structured logging with JSON output
- **Tracing**: Ready for distributed tracing integration

## High Availability

- **Pod Distribution**: Anti-affinity rules
- **Disruption Budgets**: Prevent all pods from being evicted
- **Auto Scaling**: HPA based on CPU and memory
- **Rolling Updates**: Zero-downtime deployments

## Resource Requirements

### Development

- **Backend**: 250m CPU, 512Mi RAM (requests)
- **Frontend**: 100m CPU, 256Mi RAM (requests)
- **PostgreSQL**: 250m CPU, 512Mi RAM
- **Redis**: 100m CPU, 256Mi RAM

### Production

- **Backend**: 500m CPU, 1Gi RAM (requests), 1000m CPU, 2Gi RAM (limits)
- **Frontend**: 250m CPU, 512Mi RAM (requests), 500m CPU, 1Gi RAM (limits)
- **HPA**: 2-20 backend pods, 2-10 frontend pods

## Deployment Environments

### Development

- **Purpose**: Local development and testing
- **Infrastructure**: Embedded databases
- **Domain**: `mcp.dev.example.com`
- **TLS**: Self-signed or disabled
- **Scaling**: Fixed replicas

### Production

- **Purpose**: Production workloads
- **Infrastructure**: AWS managed services
- **Domain**: `mcp.example.com`
- **TLS**: AWS ACM certificate
- **Scaling**: Auto-scaling enabled

## Common Commands

### Deployment

```bash
# Install development
cd anysource-chart
helm upgrade --install anysource . -f values-dev.yaml --namespace anysource --create-namespace

# Install production
helm upgrade --install anysource . -f values-aws-prod.yaml --namespace anysource --create-namespace

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

## Migration from Terraform

This Helm chart provides equivalent functionality to the Terraform deployment with these key differences:

| Aspect            | Terraform           | Kubernetes                   |
| ----------------- | ------------------- | ---------------------------- |
| **Orchestration** | ECS/Fargate         | Kubernetes pods              |
| **Networking**    | ALB + VPC           | Ingress + Services           |
| **Scaling**       | ECS Auto Scaling    | HPA                          |
| **Secrets**       | AWS Secrets Manager | Kubernetes Secrets           |
| **Monitoring**    | CloudWatch          | Prometheus                   |
| **Databases**     | RDS/ElastiCache     | Can use external or embedded |

### Deployment Order

When starting from scratch on AWS:

1. **Create VPC and networking** (use existing Terraform or AWS console)
2. **Provision EKS cluster** (optional: use `terraform-eks/` module)
3. **Deploy Anysource** (use `anysource-chart/` Helm chart)

The EKS Terraform module is designed to work with existing VPC infrastructure and can be used independently of the main application deployment.

## Support

- **Documentation**: See [anysource-chart/README.md](./anysource-chart/README.md) for detailed chart documentation
- **EKS Setup**: See [terraform-eks/README.md](./terraform-eks/README.md) for EKS cluster provisioning
- **Issues**: Report issues to the Anysource team
- **Contact**: team@anysource.dev

## Contributing

1. Test changes locally with development values
2. Validate with `helm template` and `helm lint`
3. Test on staging environment before production
4. Follow semantic versioning for chart versions
