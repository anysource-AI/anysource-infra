# AWS EKS Terraform Module

This Terraform module provisions an Amazon EKS (Elastic Kubernetes Service) cluster optimized for running applications. It provides production-ready defaults while remaining flexible for different environments and projects.

## Features

- **EKS Cluster**: Creates an EKS cluster with configurable Kubernetes version
- **Managed Node Groups**: Configurable EKS managed node groups with auto-scaling
- **Security**: KMS encryption for Kubernetes secrets
- **IRSA Support**: IAM Roles for Service Accounts (IRSA) enabled
- **Add-ons**: Essential EKS add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI driver, metrics-server, CloudWatch Observability)
- **Networking**: Works with existing VPC and subnets, auto-discovery with proper tagging
- **Security**: API access restrictions, private endpoints, IP whitelisting, encryption at rest
- **Integration**: Designed for application Helm charts with proper IRSA and load balancer support

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0
3. **VPC**: Either create a new VPC or use an existing one with private subnets (and optionally public subnets)
4. **kubectl** for cluster access (optional)

## Deployment Modes

This module supports three deployment modes to fit different infrastructure requirements:

1. **Full Stack** (Default): Create new VPC + new EKS cluster

   - Best for: New deployments, greenfield projects
   - Creates: VPC, EKS cluster, RDS, Redis, S3, all IAM roles

2. **Existing VPC**: Use existing VPC + create new EKS cluster

   - Best for: Integrating with existing network infrastructure
   - Creates: EKS cluster, RDS, Redis, S3, all IAM roles
   - Requires: Existing VPC with properly tagged subnets

3. **Existing EKS**: Use existing VPC + existing EKS cluster
   - Best for: Adding application infrastructure to existing cluster
   - Creates: Application IRSA role, RDS, Redis, S3
   - Requires: Existing EKS cluster with OIDC provider

## Quick Start

### Mode 1: Full Stack (Recommended for New Deployments)

1. **Clone and navigate to the module**:
   ```bash
   cd infra/aws-helm/terraform-eks
   ```
2. **Copy the example tfvars file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. **Edit `terraform.tfvars`** with your values:

   ```hcl
   # Required values
   region  = "us-east-1"
   account = "123456789012"

   # VPC Configuration - Create new VPC
   create_vpc = true
   vpc_cidr   = "10.0.0.0/16"

   # EKS Configuration - Create new cluster
   create_eks = true
   cluster_version = "1.33"

   # Database and Redis secrets
   database_password = "your-strong-password"
   secret_key       = "your-secret-key"
   master_salt      = "your-master-salt"
   auth_api_key     = "your-auth-api-key"
   ```

4. **Initialize and plan**:
   ```bash
   terraform init
   terraform plan
   ```
5. **Apply the configuration**:
   ```bash
   terraform apply
   ```
6. **Configure kubectl** (after cluster creation):
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name myproject-development-eks
   ```
7. **Deploy your application** using Helm charts with proper IRSA configuration

### Mode 2: Existing VPC

See [Using Existing VPC](#using-existing-vpc) section below.

### Mode 3: Existing EKS Cluster

See [Using Existing EKS Cluster](#using-existing-eks-cluster) section below.

## Configuration

### Required Variables

| Variable            | Description              | Example                  |
| ------------------- | ------------------------ | ------------------------ |
| `region`            | AWS region               | `"us-east-1"`            |
| `account`           | AWS Account ID           | `"412677576004"`         |
| `database_password` | Database master password | `"your-strong-password"` |
| `secret_key`        | Application secret key   | `"your-secret-key"`      |
| `master_salt`       | Application master salt  | `"your-master-salt"`     |
| `auth_api_key`      | Authentication API key   | `"your-auth-api-key"`    |

### Optional Variables

| Variable             | Description        | Default                         |
| -------------------- | ------------------ | ------------------------------- |
| `cluster_name`       | EKS cluster name   | `"{project}-{environment}-eks"` |
| `cluster_version`    | Kubernetes version | `"1.28"`                        |
| `private_subnet_ids` | Private subnet IDs | Auto-discovered                 |
| `public_subnet_ids`  | Public subnet IDs  | Auto-discovered                 |
| `environment`        | Environment name   | `"development"`                 |

### Node Groups Configuration

Configure node groups in `terraform.tfvars`:

```hcl
node_groups = {
  default = {
    instance_types = ["t3.medium"]
    scaling_config = {
      desired_size = 2
      max_size     = 4
      min_size     = 1
    }
    disk_size = 50
  }
}
```

### Cluster Add-ons

Essential add-ons are enabled by default with optimized configuration:

```hcl
cluster_addons = {
  # Critical add-ons that MUST be installed AND active before nodes join
  vpc-cni = {
    before_compute = true # CNI must be active for nodes to get network interfaces
  }
  kube-proxy = {
    before_compute = true # Network proxy needed for service communication
  }
  # Additional add-ons (can be installed alongside node group creation)
  aws-ebs-csi-driver              = {}
  eks-pod-identity-agent          = {}
  coredns                         = {}
  metrics-server                  = {}
  amazon-cloudwatch-observability = {}
}
```

**Available Add-ons:**

- **CoreDNS**: Cluster DNS service
- **kube-proxy**: Network proxy for service communication (installed before compute nodes)
- **vpc-cni**: AWS VPC CNI plugin for pod networking (installed before compute nodes)
- **aws-ebs-csi-driver**: EBS CSI driver for persistent volumes (uses IRSA for AWS API access)
- **eks-pod-identity-agent**: Pod identity agent for IRSA
- **metrics-server**: Kubernetes metrics server
- **amazon-cloudwatch-observability**: Unified observability with CloudWatch logs, metrics, and traces (uses IRSA for AWS API access)

**Note**: The AWS EBS CSI Driver and Amazon CloudWatch Observability addons are automatically configured with IRSA (IAM Role for Service Accounts) roles. The module creates the required IAM roles and attaches them to the respective service accounts. Critical add-ons (vpc-cni and kube-proxy) are installed before compute nodes join the cluster to ensure proper networking.

## Networking Requirements

### VPC Requirements

Your existing VPC should have:

- **Private subnets** for EKS nodes (required)
- **Public subnets** for load balancers (optional but recommended)
- **Internet Gateway** for public subnets
- **NAT Gateway** for private subnet internet access

### Subnet Tagging

The module will auto-discover subnets if not specified. For auto-discovery to work, tag your subnets:

**Private subnets**:

```
Type = "private"
kubernetes.io/role/internal-elb = "1"
kubernetes.io/cluster/<cluster-name> = "shared"
```

**Public subnets**:

```
Type = "public"
kubernetes.io/role/elb = "1"
kubernetes.io/cluster/<cluster-name> = "shared"
```

Alternatively, specify subnet IDs directly in `terraform.tfvars`:

```hcl
private_subnet_ids = ["subnet-12345", "subnet-67890", "subnet-abcde"]
public_subnet_ids  = ["subnet-fghij", "subnet-klmno", "subnet-pqrst"]
```

## Outputs

The module provides comprehensive outputs including:

- `cluster_endpoint` - EKS cluster API endpoint
- `cluster_name` - EKS cluster name
- `cluster_arn` - EKS cluster ARN
- `oidc_provider_arn` - OIDC provider ARN for IRSA
- `cluster_security_group_id` - Cluster security group ID
- `ebs_csi_driver_role_arn` - ARN of the IAM role for AWS EBS CSI Driver (IRSA)
- `cloudwatch_observability_role_arn` - ARN of the IAM role for Amazon CloudWatch Observability (IRSA)

## Security Considerations

### Production Recommendations

1. **Restrict API access**:
   ```hcl
   cluster_endpoint_public_access_cidrs = ["10.0.0.0/8"]  # Your corporate CIDR
   ```
2. **Enable private endpoint**:
   ```hcl
   cluster_endpoint_private_access = true
   cluster_endpoint_public_access  = false  # For private-only access
   ```
3. **Configure whitelist IPs for enhanced security**:
   ```hcl
   whitelist_ips = ["203.0.113.1/32", "198.51.100.0/24"]
   ```
   This automatically creates security group rules to restrict EKS control plane access to only the specified IPs.
4. **Add custom security group rules**:
   ```hcl
   cluster_security_group_additional_rules = {
     admin_access = {
       description = "Admin access from office network"
       protocol    = "tcp"
       from_port   = 443
       to_port     = 443
       type        = "ingress"
       cidr_blocks = ["192.168.1.0/24"]
     }
   }
   ```
5. **Use encryption**:
   ```hcl
   enable_cluster_encryption = true
   ```

### Access Control

The module creates a KMS key for encryption and configures basic RBAC. You may need to configure additional IAM roles and policies based on your requirements.

## Troubleshooting

### Common Issues

1. **Subnet discovery fails**: Ensure subnets are properly tagged or specify IDs directly
2. **Access denied**: Verify AWS credentials and IAM permissions
3. **Node group creation fails**: Check subnet capacity and instance limits
4. **Load Balancer Controller ACM errors**: The module automatically creates the necessary ACM permissions for certificate management

### IAM Roles for Service Accounts (IRSA)

The module automatically configures IRSA roles for the following components:

**AWS EBS CSI Driver**:

- Dedicated IRSA role with EBS permissions
- Attached to `kube-system:ebs-csi-controller-sa` service account
- Enables the CSI driver to create and manage EBS volumes
- Available output: `ebs_csi_driver_role_arn`

**Amazon CloudWatch Observability**:

- Dedicated IRSA role with CloudWatch permissions
- Attached to `amazon-cloudwatch:cloudwatch-agent` service account
- Enables unified observability with logs, metrics, and traces
- Available output: `cloudwatch_observability_role_arn`

**AWS Load Balancer Controller**:

- Dedicated IRSA role with ACM and ELB permissions
- Proper certificate management policies
- Secure credential management via service accounts
- Available output: `load_balancer_controller_role_arn`

**Application**:

- Dedicated IRSA role with Bedrock, S3, and Secrets Manager permissions
- Available output: `application_service_account_role_arn`

This resolves common permission issues when using AWS services from within pods.

### Useful Commands

```bash
# Check cluster status
aws eks describe-cluster --name <your-cluster-name> --region <your-region>
# Update kubeconfig
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
# List nodes
kubectl get nodes
# Check add-ons
aws eks describe-addon --cluster-name <your-cluster-name> --addon-name vpc-cni --region <your-region>
```

## Cost Optimization

### Environment-based Defaults

The module automatically adjusts defaults based on environment:

**Development**:

- Smaller instance sizes
- Lower backup retention

**Production**:

- On-demand instances
- Larger instance sizes
- Extended backup retention
- Multi-AZ configurations

### Cost-saving Tips

1. Enable **cluster autoscaler** for dynamic scaling
2. Use **smaller instance types** for development
3. Consider **Fargate** for sporadic workloads

## Module Structure

```
terraform-eks/
├── data.tf              # Data sources
├── eks.tf               # Main EKS configuration
├── locals.tf            # Local values and computations
├── outputs.tf           # Module outputs
├── provider.tf          # Provider configuration
├── variables.tf         # Input variables
├── versions.tf          # Provider version constraints
├── terraform.tfvars.example  # Example configuration
└── README.md           # This file
```

## Contributing

When making changes:

1. Update variable descriptions and validation rules
2. Test with different environment configurations
3. Update documentation for any new features
4. Follow Terraform best practices

## Using as a Terraform Module

You can use this module from another Terraform project instead of running it directly.

### Module Reference

```hcl
module "eks_infrastructure" {
  source = "git::https://github.com/anysource-AI/anysource.git//infra/aws-helm/terraform-eks?ref=v1.0.0"

  # Or use local path if you have the repository cloned
  # source = "../../anysource/infra/aws-helm/terraform-eks"

  # Core Configuration
  environment = "production"
  project     = "myapp"
  region      = "us-east-1"
  account     = "123456789012"

  # EKS Configuration
  create_eks      = true
  cluster_version = "1.33"

  # VPC Configuration
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"

  # Node Groups
  node_groups = {
    default = {
      instance_types = ["m6i.2xlarge"]
      scaling_config = {
        desired_size = 4
        max_size     = 10
        min_size     = 2
      }
      disk_size = 50
    }
  }

  # Database Configuration
  database_name     = "myapp_db"
  database_username = "dbadmin"
  database_password = var.database_password  # Pass from parent module
  database_config = {
    engine_version = "16.8"
    min_capacity   = 2
    max_capacity   = 16
  }

  # Redis Configuration
  redis_node_type = "cache.t3.medium"

  # Application Secrets
  secret_key   = var.secret_key
  master_salt  = var.master_salt
  auth_api_key = var.auth_api_key

  # Monitoring
  enable_monitoring = true

  # EKS Namespace
  eks_namespace = "myapp-production"
}
```

### Required Variables

When using as a module, you must provide:

| Variable            | Type   | Description                                         |
| ------------------- | ------ | --------------------------------------------------- |
| `region`            | string | AWS region                                          |
| `account`           | string | AWS Account ID                                      |
| `environment`       | string | Environment name (development, staging, production) |
| `project`           | string | Project name                                        |
| `database_password` | string | Database master password                            |
| `secret_key`        | string | Application secret key                              |
| `master_salt`       | string | Application master salt                             |
| `auth_api_key`      | string | Authentication API key                              |
| `eks_namespace`     | string | Kubernetes namespace for the application            |

### Available Outputs

The module provides these outputs:

| Output                                 | Description                                                |
| -------------------------------------- | ---------------------------------------------------------- |
| `cluster_name`                         | EKS cluster name                                           |
| `cluster_endpoint`                     | EKS cluster API endpoint                                   |
| `cluster_arn`                          | EKS cluster ARN                                            |
| `oidc_provider_arn`                    | OIDC provider ARN for IRSA                                 |
| `cluster_security_group_id`            | Cluster security group ID                                  |
| `vpc_id`                               | VPC ID (if created)                                        |
| `private_subnet_ids`                   | Private subnet IDs                                         |
| `public_subnet_ids`                    | Public subnet IDs                                          |
| `database_endpoint`                    | RDS database endpoint                                      |
| `redis_endpoint`                       | Redis endpoint                                             |
| `application_service_account_role_arn` | IAM role ARN for application IRSA                          |
| `ebs_csi_driver_role_arn`              | IAM role ARN for EBS CSI driver (null if create_eks=false) |
| `load_balancer_controller_role_arn`    | IAM role ARN for ALB controller (null if create_eks=false) |
| `cloudwatch_observability_role_arn`    | IAM role ARN for CloudWatch (null if create_eks=false)     |

### Example: Using Module Outputs

```hcl
# Use module outputs in your Terraform configuration
output "eks_cluster_name" {
  value = module.eks_infrastructure.cluster_name
}

output "database_connection_string" {
  value     = "postgresql://${module.eks_infrastructure.database_endpoint}:5432/myapp_db"
  sensitive = true
}

# Use outputs for Helm deployment
resource "helm_release" "myapp" {
  name       = "myapp"
  repository = "https://charts.myapp.com"
  chart      = "myapp"
  namespace  = "myapp-production"

  set {
    name  = "database.host"
    value = module.eks_infrastructure.database_endpoint
  }

  set {
    name  = "redis.host"
    value = module.eks_infrastructure.redis_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks_infrastructure.application_service_account_role_arn
  }
}
```

## Using Existing VPC

You can deploy the EKS cluster into an existing VPC instead of creating a new one.

### Prerequisites

Your existing VPC must have:

1. **Private Subnets** (required):

   - At least 2 private subnets across different AZs
   - NAT Gateway or NAT instance for internet access
   - Route table with route to NAT Gateway

2. **Public Subnets** (recommended):

   - At least 2 public subnets across different AZs
   - Internet Gateway attached to VPC
   - Route table with route to Internet Gateway

3. **Subnet Tagging** (for auto-discovery):

   ```
   # Private subnets
   kubernetes.io/role/internal-elb = "1"
   kubernetes.io/cluster/<cluster-name> = "shared"

   # Public subnets
   kubernetes.io/role/elb = "1"
   kubernetes.io/cluster/<cluster-name> = "shared"
   ```

4. **VPC Requirements**:
   - DNS hostnames enabled
   - DNS resolution enabled
   - Sufficient IP address space for pods and services

### Configuration

```hcl
# terraform.tfvars
region  = "us-east-1"
account = "123456789012"

# Use existing VPC
create_vpc = false
vpc_id     = "vpc-0a1b2c3d4e5f67890"

# Provide existing subnet IDs
private_subnet_ids = ["subnet-0a1b2c3d", "subnet-1e2f3g4h", "subnet-2i3j4k5l"]
public_subnet_ids  = ["subnet-6m7n8o9p", "subnet-7q8r9s0t", "subnet-8u9v0w1x"]

# EKS Configuration
create_eks      = true
cluster_version = "1.33"

# ... rest of configuration
```

### Subnet Tagging Script

If your subnets aren't tagged, use this script:

```bash
#!/bin/bash
CLUSTER_NAME="myproject-production-eks"
REGION="us-east-1"

# Tag private subnets
aws ec2 create-tags --region $REGION \
  --resources subnet-0a1b2c3d subnet-1e2f3g4h subnet-2i3j4k5l \
  --tags \
    Key=kubernetes.io/role/internal-elb,Value=1 \
    Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared

# Tag public subnets
aws ec2 create-tags --region $REGION \
  --resources subnet-6m7n8o9p subnet-7q8r9s0t subnet-8u9v0w1x \
  --tags \
    Key=kubernetes.io/role/elb,Value=1 \
    Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared
```

### Networking Considerations

**NAT Gateway**:

- Production: Use one NAT Gateway per AZ for high availability
- Development: Single NAT Gateway is acceptable

**Security Groups**:

- The module creates its own security groups for EKS
- Ensure VPC security groups allow traffic between subnets

**VPC Flow Logs**:

- Consider enabling VPC Flow Logs for network monitoring
- The module does not modify existing VPC Flow Log settings

## Using Existing EKS Cluster

You can use this module to provision application infrastructure (RDS, Redis, S3, IAM roles) for an existing EKS cluster.

### When to Use This Mode

- You have an existing EKS cluster managed outside Terraform
- You want to add application infrastructure without modifying the cluster
- Multiple applications share the same EKS cluster
- Cluster is managed by a platform team, applications by app teams

### Prerequisites

Before using `create_eks = false`, you need:

1. **Existing EKS Cluster**:

   - Cluster must be running and accessible
   - Kubernetes version 1.19 or higher

2. **OIDC Provider**:

   - OIDC provider must be enabled on the cluster
   - You need the OIDC provider ARN

3. **Required Add-ons** (must be installed):

   - VPC CNI
   - kube-proxy
   - CoreDNS
   - EBS CSI Driver (with IRSA role)
   - AWS Load Balancer Controller (with IRSA role)

4. **Cluster Information**:
   - Cluster name
   - OIDC provider ARN

### Get OIDC Provider ARN

```bash
# Get OIDC provider ARN for your cluster
aws eks describe-cluster \
  --name your-cluster-name \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text

# Output: https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE

# Convert to ARN format
# arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
```

### Configuration

```hcl
# terraform.tfvars
region  = "us-east-1"
account = "123456789012"

# Use existing VPC (required when using existing EKS)
create_vpc = false
vpc_id     = "vpc-0a1b2c3d4e5f67890"
private_subnet_ids = ["subnet-0a1b2c3d", "subnet-1e2f3g4h", "subnet-2i3j4k5l"]
public_subnet_ids  = ["subnet-6m7n8o9p", "subnet-7q8r9s0t", "subnet-8u9v0w1x"]

# Use existing EKS cluster
create_eks                 = false
existing_cluster_name      = "my-existing-cluster"
existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"

# Database Configuration
database_name     = "myapp_db"
database_username = "dbadmin"
database_password = "your-strong-password"
database_config = {
  engine_version = "16.8"
  min_capacity   = 2
  max_capacity   = 16
}

# Redis Configuration
redis_node_type = "cache.t3.medium"

# Application Secrets
secret_key   = "your-secret-key"
master_salt  = "your-master-salt"
auth_api_key = "your-auth-api-key"

# EKS Namespace
eks_namespace = "myapp-production"
```

### What Gets Created

When `create_eks = false`, the module creates:

✅ **Application IRSA Role**: IAM role for your application pods (Bedrock, S3, Secrets Manager access)
✅ **RDS Database**: Aurora PostgreSQL Serverless v2
✅ **Redis Cache**: ElastiCache Redis
✅ **S3 Buckets**: Optional S3 buckets for application data
✅ **Secrets**: AWS Secrets Manager secrets for application configuration
✅ **Security Groups**: For RDS and Redis

### What Does NOT Get Created

When `create_eks = false`, the module does NOT create:

❌ **EKS Cluster**: Uses your existing cluster
❌ **Node Groups**: Uses your existing nodes
❌ **Cluster Add-ons**: Uses your existing add-ons
❌ **System IRSA Roles**: EBS CSI Driver, ALB Controller, CloudWatch roles
❌ **KMS Key**: Uses your existing cluster encryption

### Outputs with Existing Cluster

Some outputs will be `null` when using an existing cluster:

```hcl
# Available outputs
cluster_name                           = "my-existing-cluster"
cluster_endpoint                       = "<existing-cluster-endpoint>"
oidc_provider_arn                      = "<your-oidc-provider-arn>"
application_service_account_role_arn   = "<newly-created-role-arn>"
database_endpoint                      = "<newly-created-rds-endpoint>"
redis_endpoint                         = "<newly-created-redis-endpoint>"

# These will be null
ebs_csi_driver_role_arn                = null
load_balancer_controller_role_arn      = null
cloudwatch_observability_role_arn      = null
```

### Example: Multiple Applications on Same Cluster

```hcl
# Application 1
module "app1_infrastructure" {
  source = "./terraform-eks"

  create_eks                 = false
  existing_cluster_name      = "shared-cluster"
  existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/..."

  project       = "app1"
  eks_namespace = "app1-production"

  # App1-specific database and secrets
  database_name = "app1_db"
  # ... other configuration
}

# Application 2
module "app2_infrastructure" {
  source = "./terraform-eks"

  create_eks                 = false
  existing_cluster_name      = "shared-cluster"
  existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/..."

  project       = "app2"
  eks_namespace = "app2-production"

  # App2-specific database and secrets
  database_name = "app2_db"
  # ... other configuration
}
```

## VPC Configuration Options

The module supports two VPC deployment modes:

### Option 1: Create New VPC (Recommended)

```hcl
create_vpc = true
vpc_cidr   = "10.0.0.0/16"

# Subnet CIDR blocks
private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

# Availability zones (auto-discovered if empty)
region_az = [] # e.g., ["us-east-1a", "us-east-1b", "us-east-1c"]
```

**Benefits:**

- Complete control over network configuration
- Automatic NAT Gateway configuration (1 for non-prod, 3 for production)
- VPC Flow Logs enabled by default
- Proper subnet tagging for auto-discovery

### Option 2: Use Existing VPC

```hcl
create_vpc = false
vpc_id     = "vpc-12345678"

# Provide existing subnet IDs
private_subnet_ids = ["subnet-12345", "subnet-67890", "subnet-abcde"]
public_subnet_ids  = ["subnet-fghij", "subnet-klmno", "subnet-pqrst"]
```

**Benefits:**

- Integrate with existing network infrastructure
- Reuse existing NAT Gateways and routing
- Maintain existing security groups and ACLs

## Database Configuration

The module creates an Aurora PostgreSQL cluster with the following features:

### Multi-AZ Configuration

- **Production**: 2 instances with automatic failover
- **Development/Staging**: 1 instance for cost optimization

### Serverless v2 Scaling

```hcl
database_config = {
  engine_version = "16.8"
  min_capacity   = 2    # Minimum ACUs
  max_capacity   = 16   # Maximum ACUs
  force_ssl      = false
}
```

### Security Features

- Encryption at rest enabled
- Private subnets only
- Security group restricting access to VPC CIDR
- SSL enforcement configurable

## Redis Configuration

ElastiCache Redis cluster with environment-aware configuration:

### Multi-AZ Support

- **Production**: 2 cache clusters with automatic failover
- **Development/Staging**: 1 cache cluster

### Security Features

```hcl
redis_node_type  = "cache.t3.medium"
```

- Encryption at rest and in transit
- Auth token authentication
- Private subnets only
- Security group restricting access to VPC CIDR

## Secrets Management

All application secrets are stored in AWS Secrets Manager:

```hcl
# Required secrets
database_password = "your-strong-password"
secret_key       = "your-secret-key"
master_salt      = "your-master-salt"
auth_api_key     = "your-auth-api-key"

# Optional secrets
sentry_dsn = "" # Sentry DSN for error tracking
```

**Security Features:**

- No random password generation (user-provided values)
- 7-day recovery window
- Automatic rotation support
- Integration with EKS IRSA for secure access

## Monitoring and Alarms

CloudWatch monitoring is available for all infrastructure components:

### Enable Monitoring

```hcl
enable_monitoring = true
```

### RDS Alarms

- CPU utilization (>80%)
- Database connections (>50)
- Freeable memory (<256MB)

### ElastiCache Alarms

- CPU utilization (>75%)
- Memory usage (>80%)
- Network bytes in (>100MB)

### EKS Alarms

- ALB 5xx errors
- Unhealthy host count
- Target response time
- ASG CPU utilization

## S3 Bucket Configuration

Optional S3 buckets can be created:

```hcl
buckets_conf = {
  uploads = { acl = "private" }
  backups = { acl = "private" }
}
```

**Features:**

- Server-side encryption enabled
- Versioning enabled
- Bucket owner preferred object ownership

## Cost Optimization

### Environment-Aware Defaults

**Development/Staging:**

- Single NAT Gateway (saves ~$45/month per AZ)
- Single Redis instance
- Single RDS instance
- Smaller instance types

**Production:**

- 3 NAT Gateways (one per AZ)
- Multi-AZ Redis with failover
- Multi-AZ RDS with failover
- Larger instance types

### Cost-Saving Tips

1. **Use single NAT Gateway** for non-production environments
2. **Enable cluster autoscaler** for dynamic node scaling
3. **Use smaller instance types** for development
4. **Monitor resource usage** with CloudWatch alarms

## Environment-Specific Defaults

The module automatically adjusts configurations based on the environment:

| Feature        | Development | Staging  | Production  |
| -------------- | ----------- | -------- | ----------- |
| NAT Gateways   | 1           | 1        | 3           |
| RDS Instances  | 1           | 1        | 2           |
| Redis Clusters | 1           | 1        | 2           |
| Monitoring     | Optional    | Optional | Recommended |
| Encryption     | Enabled     | Enabled  | Enabled     |

## Migration Guide

### From Existing EKS Deployments

1. **Backup existing configuration**:

   ```bash
   kubectl get all --all-namespaces -o yaml > backup.yaml
   ```

2. **Update terraform.tfvars** with new variables:

   ```hcl
   # Add new required variables
   database_password = "your-password"
   # ... other secrets
   ```

3. **Plan the migration**:

   ```bash
   terraform plan
   ```

4. **Apply changes**:
   ```bash
   terraform apply
   ```

### From ECS to EKS

1. **Export ECS configuration** to understand current setup
2. **Map ECS services** to Kubernetes deployments
3. **Update application configuration** for Kubernetes
4. **Test in staging environment** before production migration

## Security Best Practices

### Secrets Management

1. **Use strong passwords** (minimum 32 characters)
2. **Rotate secrets regularly** using AWS Secrets Manager
3. **Never commit secrets** to version control
4. **Use different secrets** for each environment

### Network Security

1. **Restrict EKS API access** to specific CIDR blocks
2. **Use private subnets** for all application resources
3. **Enable VPC Flow Logs** for network monitoring
4. **Implement least privilege** IAM policies

### Database Security

1. **Enable SSL enforcement** in production
2. **Use parameter groups** for security hardening
3. **Regular security updates** for Aurora PostgreSQL
4. **Monitor database access** with CloudWatch

## Troubleshooting

### Common Issues

1. **VPC creation fails**: Check CIDR block conflicts
2. **Database connection issues**: Verify security group rules
3. **Redis connection fails**: Check auth token and security groups
4. **Monitoring alarms not working**: Verify `enable_monitoring = true`

### Useful Commands

```bash
# Check cluster status
aws eks describe-cluster --name <cluster-name> --region <region>

# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check database connectivity
aws rds describe-db-clusters --db-cluster-identifier <cluster-id>

# Check Redis status
aws elasticache describe-replication-groups --replication-group-id <group-id>
```

## License

This module is designed to be reusable across different projects and follows standard Terraform module practices.
