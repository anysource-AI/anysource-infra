# AWS EKS Terraform Module

Provisions an EKS cluster with RDS, Redis, and application infrastructure.

## Deployment Modes

1. **Full Stack**: Create VPC + EKS + infrastructure
2. **Existing VPC**: Use existing VPC + create EKS + infrastructure  
3. **Existing EKS**: Use existing VPC + existing EKS + create infrastructure only

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- VPC (existing or will be created)

## Quick Start

### Mode 1: Full Stack

   ```bash
# 1. Copy example
   cp terraform.tfvars.example terraform.tfvars

# 2. Configure terraform.tfvars
region              = "us-east-1"
account             = "123456789012"
create_vpc          = true
vpc_cidr            = "10.0.0.0/16"
create_eks          = true
cluster_version     = "1.33"
database_password   = "your-password"
secret_key          = "your-secret-key"
master_salt         = "your-master-salt"
auth_api_key        = "your-auth-api-key"

# 3. Deploy
   terraform init
   terraform plan
   terraform apply

# 4. Configure kubectl
   aws eks update-kubeconfig --region us-east-1 --name anysource-development-eks
   ```

### Mode 2: Existing VPC

```hcl
create_vpc         = false
vpc_id             = "vpc-0a1b2c3d4e5f67890"
private_subnet_ids = ["subnet-0a1b2c3d", "subnet-1e2f3g4h", "subnet-2i3j4k5l"]
public_subnet_ids  = ["subnet-6m7n8o9p", "subnet-7q8r9s0t", "subnet-8u9v0w1x"]
create_eks         = true
# ... rest of config
```

**Subnet Tagging Required:**

```
# Private subnets
kubernetes.io/role/internal-elb = "1"
kubernetes.io/cluster/<cluster-name> = "shared"

# Public subnets
kubernetes.io/role/elb = "1"
kubernetes.io/cluster/<cluster-name> = "shared"
```

### Mode 3: Existing EKS

```hcl
create_vpc                 = false
vpc_id                     = "vpc-0a1b2c3d4e5f67890"
private_subnet_ids         = [...]
create_eks                 = false
existing_cluster_name      = "my-cluster"
existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/..."
eks_namespace              = "myapp-production"
# ... rest of config
```

**Get OIDC Provider ARN:**

```bash
aws eks describe-cluster --name your-cluster --region us-east-1 \
  --query "cluster.identity.oidc.issuer" --output text
# Output: https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE
# ARN: arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE
```

## Configuration

### Required Variables

| Variable            | Description                   |
| ------------------- | ----------------------------- |
| `region`            | AWS region                    |
| `account`           | AWS Account ID                |
| `database_password` | RDS password                  |
| `secret_key`        | Application secret            |
| `master_salt`       | Application salt              |
| `auth_api_key`      | Auth API key                  |
| `eks_namespace`     | Kubernetes namespace (mode 3) |

### Node Groups

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

```hcl
cluster_addons = {
  vpc-cni                         = { before_compute = true }
  kube-proxy                      = { before_compute = true }
  aws-ebs-csi-driver              = {}
  eks-pod-identity-agent          = {}
  coredns                         = {}
  metrics-server                  = {}
  amazon-cloudwatch-observability = {}
}
```

### SSO Admin Access (Optional)

```hcl
sso_admin_role_arn = "arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/..."

# For GitHub Actions access
kms_key_administrators = [
  "arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/...",
  "arn:aws:iam::123456789012:role/github-actions-oidc-trust-role"
]
```

## Outputs

| Output                                 | Description                        |
| -------------------------------------- | ---------------------------------- |
| `cluster_name`                         | EKS cluster name                   |
| `cluster_endpoint`                     | EKS API endpoint                   |
| `oidc_provider_arn`                    | OIDC provider for IRSA             |
| `vpc_id`                               | VPC ID (if created)                |
| `database_endpoint`                    | RDS endpoint                       |
| `redis_endpoint`                       | Redis endpoint                     |
| `application_service_account_role_arn` | IAM role for application IRSA      |
| `ebs_csi_driver_role_arn`              | IAM role for EBS CSI (mode 1 & 2)  |
| `load_balancer_controller_role_arn`    | IAM role for ALB (mode 1 & 2)      |
| `cloudwatch_observability_role_arn`    | IAM role for CloudWatch (mode 1-2) |

## Security

   ```hcl
# Restrict API access
cluster_endpoint_public_access_cidrs = ["10.0.0.0/8"]

# Private endpoint only
   cluster_endpoint_private_access = true
cluster_endpoint_public_access  = false

# IP allowlist
whitelist_ips = ["203.0.113.1/32"]

# Encryption
   enable_cluster_encryption = true
   ```

## Using as Module

```hcl
module "eks" {
  source = "git::https://github.com/anysource-AI/runlayer-infra.git//aws-helm/terraform-eks?ref=v1.0.0"

  region             = "us-east-1"
  account            = "123456789012"
  environment        = "production"
  project            = "myapp"
  create_eks         = true
  cluster_version    = "1.33"
  create_vpc         = true
  vpc_cidr           = "10.0.0.0/16"
  database_password  = var.database_password
  secret_key         = var.secret_key
  master_salt        = var.master_salt
  auth_api_key       = var.auth_api_key
  eks_namespace      = "myapp-production"
}
```

## Troubleshooting

```bash
# Check cluster
aws eks describe-cluster --name <cluster-name> --region <region>

# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check nodes
kubectl get nodes

# Check add-ons
aws eks describe-addon --cluster-name <cluster-name> --addon-name vpc-cni --region <region>

# Check database
aws rds describe-db-clusters --db-cluster-identifier <cluster-id>

# Check Redis
aws elasticache describe-replication-groups --replication-group-id <group-id>
```
