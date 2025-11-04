# Example: Using the EKS Terraform Module

This directory contains an example of how to use the EKS Terraform module to deploy a complete EKS cluster with all necessary infrastructure.

## Overview

This directory contains three deployment scenarios:

1. **New VPC + New EKS Cluster** (MODE 1 - Default): Deploy a complete EKS cluster with new VPC, RDS, Redis, and application infrastructure
2. **Existing VPC + New EKS Cluster** (MODE 2): Deploy a new EKS cluster in an existing VPC with RDS, Redis, and application infrastructure
3. **Existing VPC + Existing EKS Cluster** (MODE 3): Add application infrastructure (RDS, Redis, IAM roles) to an existing EKS cluster

## Files

All configuration files support all three deployment modes:

- **`main.tf`** - Main Terraform configuration with MODE 1, MODE 2, and MODE 3 sections
- **`variables.tf`** - Variable definitions for all modes
- **`outputs.tf`** - Outputs for all modes (some outputs only apply to MODE 1 and MODE 2)
- **`terraform.tfvars.example`** - Example values with MODE 1, MODE 2, and MODE 3 sections
- **`.gitignore`** - Prevents committing sensitive files
- **`README.md`** - This file

**Note**: Each file contains all three modes. Simply comment/uncomment the appropriate sections based on your deployment scenario.

## Switching Between Modes

All configuration files are designed to support all three modes. To switch between them:

1. **In `terraform.tfvars`**: Comment/uncomment the MODE sections
2. **In `main.tf`**: Comment/uncomment the module blocks (only one module block should be active)
3. **In `outputs.tf`**: Comment out MODE 1/2 specific outputs when using MODE 3

**Quick Reference:**
- **MODE 1 Active** (New VPC + New EKS): Default configuration, uses new VPC
- **MODE 2 Active** (Existing VPC + New EKS): Set `create_vpc = false`, creates new EKS cluster
- **MODE 3 Active** (Existing VPC + Existing EKS): Set `create_vpc = false` and `create_eks = false`, comment out cluster-specific outputs

## Usage

Choose one of the deployment modes below based on your needs:

### Mode 1: New VPC + New EKS Cluster (Full Stack)

Use this when deploying a complete new EKS cluster with all infrastructure.

#### 1. Copy the Example Files

```bash
# Create a new directory for your deployment
mkdir -p my-deployment
cd my-deployment

# Copy the example files
cp /path/to/terraform-eks/example/main.tf .
cp /path/to/terraform-eks/example/variables.tf .
cp /path/to/terraform-eks/example/outputs.tf .
cp /path/to/terraform-eks/example/terraform.tfvars.example terraform.tfvars
cp /path/to/terraform-eks/example/.gitignore .
```

#### 2. Update Configuration

Edit `terraform.tfvars`:
- Set `release_version` to the desired module version (e.g., "v1.0.0", "v1.1.0")
- Keep **MODE 1** section active (already uncommented)
- Ensure **MODE 2** and **MODE 3** sections are commented out
- Update the COMMON CONFIGURATION section with your values:
  - Network configuration (VPC CIDR, subnets)
  - Database password
  - Application secrets (secret_key, master_salt)
  - Auth API key
  - EKS namespace

Edit `main.tf` to customize:
- `locals` block with your project name, environment, region, and AWS account ID
- Module source (use git URL or local path)
- Ensure **MODE 1** section is active (uncommented)
- Ensure **MODE 2** and **MODE 3** sections are commented out
- SSO admin role ARN (if using AWS SSO)
- Node group configuration
- Access entries for additional IAM roles

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

---

### Mode 2: Existing VPC + New EKS Cluster

Use this when you have an existing VPC and want to deploy a new EKS cluster within it.

#### 1. Copy the Example Files

```bash
# Create a new directory for your deployment
mkdir -p my-deployment
cd my-deployment

# Copy the example files
cp /path/to/terraform-eks/example/main.tf .
cp /path/to/terraform-eks/example/variables.tf .
cp /path/to/terraform-eks/example/outputs.tf .
cp /path/to/terraform-eks/example/terraform.tfvars.example terraform.tfvars
cp /path/to/terraform-eks/example/.gitignore .
```

#### 2. Update Configuration

Edit `terraform.tfvars`:
- Set `release_version` to the desired module version (e.g., "v1.0.0", "v1.1.0")
- Comment out **MODE 1** section
- Uncomment **MODE 2** section and update with your values:
  - VPC ID and subnet IDs (from existing VPC)
- Ensure **MODE 3** section is commented out
- Update the COMMON CONFIGURATION section with your values:
  - Database password
  - Application secrets (secret_key, master_salt)
  - Auth API key
  - EKS namespace

Edit `main.tf`:
- `locals` block with your project name, environment, region, and AWS account ID
- Module source (use git URL or local path)
- Comment out **MODE 1** module section
- Uncomment **MODE 2** module section
- Ensure **MODE 3** section is commented out
- SSO admin role ARN (if using AWS SSO)
- Node group configuration
- Access entries for additional IAM roles

#### 3. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

---

### Mode 3: Existing VPC + Existing EKS Cluster (Application Infrastructure Only)

Use this when you have an existing EKS cluster and want to add application infrastructure (RDS, Redis, IAM roles) without modifying the cluster.

#### Prerequisites

Before using this mode, ensure you have:

1. **Existing EKS Cluster** running and accessible (Kubernetes 1.19+)
2. **OIDC Provider** enabled on the cluster
3. **Required Add-ons** installed:
   - VPC CNI
   - kube-proxy
   - CoreDNS
   - EBS CSI Driver (with IRSA role)
   - AWS Load Balancer Controller (with IRSA role)

#### 1. Get OIDC Provider ARN

```bash
# Get OIDC provider URL for your cluster
aws eks describe-cluster \
  --name your-cluster-name \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text

# Output: https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE

# Convert to ARN format:
# arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
```

#### 2. Copy the Example Files

```bash
# Create a new directory for your deployment
mkdir -p my-app-infrastructure
cd my-app-infrastructure

# Copy all example files
cp /path/to/terraform-eks/example/main.tf .
cp /path/to/terraform-eks/example/variables.tf .
cp /path/to/terraform-eks/example/outputs.tf .
cp /path/to/terraform-eks/example/terraform.tfvars.example terraform.tfvars
cp /path/to/terraform-eks/example/.gitignore .
```

#### 3. Update Configuration

Edit `terraform.tfvars`:
- Set `release_version` to the desired module version (e.g., "v1.0.0", "v1.1.0")
- Comment out **MODE 1** and **MODE 2** sections
- Uncomment **MODE 3** section and update with your values:
  - VPC ID and subnet IDs (from existing VPC)
  - Existing EKS cluster name
  - OIDC provider ARN (from step 1)
- Update the COMMON CONFIGURATION section with your values:
  - Database password
  - Application secrets (secret_key, master_salt)
  - Auth API key
  - EKS namespace

Edit `main.tf`:
- `locals` block with your project name, environment, region, and AWS account ID
- Module source (use git URL or local path)
- Comment out **MODE 1** and **MODE 2** module sections
- Uncomment **MODE 3** module section

Edit `outputs.tf`:
- Comment out MODE 1 and MODE 2 specific outputs (cluster_name, cluster_endpoint, etc.)
- Keep common outputs active

#### 4. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

#### What Gets Created

When using an existing EKS cluster, the module creates:

✅ **Application IRSA Role**: IAM role for your application pods  
✅ **RDS Database**: Aurora PostgreSQL Serverless v2  
✅ **Redis Cache**: ElastiCache Redis  
✅ **Bedrock Guardrail**: AWS Bedrock guardrail for AI safety  
✅ **Secrets Manager**: Application secrets storage  

❌ **Does NOT create**: EKS cluster, node groups, VPC, subnets, EKS add-ons

## Key Configuration Options

### SSO Admin Access (Optional)

If you have AWS SSO configured and want to use it for admin access, you can specify the SSO admin role ARN:

```hcl
sso_admin_role_arn = "arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess_xxxxx"
enable_cluster_creator_admin_permissions = false
```

For deployments without SSO (most common), you can omit this or use the default settings:

```hcl
# sso_admin_role_arn = "" # Leave empty or omit
enable_cluster_creator_admin_permissions = true # Default
```

### CI/CD Access

To add CI/CD pipeline access (e.g., GitHub Actions, GitLab CI, Jenkins), include in `access_entries`:

```hcl
access_entries = {
  cicd_role = {
    principal_arn = "arn:aws:iam::${local.account}:role/your-cicd-role"
    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
    kubernetes_groups = []
    type              = "STANDARD"
  }
}
```

Also add to KMS administrators:

```hcl
kms_key_administrators = [
  "arn:aws:iam::${local.account}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess_xxxxx",
  "arn:aws:iam::${local.account}:role/your-cicd-role"
]
```

### Node Group Configuration

Customize node groups based on your workload:

```hcl
node_groups = {
  default = {
    instance_types = ["m6i.2xlarge"]
    scaling_config = {
      desired_size = 6
      max_size     = 20
      min_size     = 4
    }
    labels = {
      Environment = local.environment
      NodeGroup   = "default"
    }
  }
}
```

## Module Source and Versioning

The module source is configured using the `release_version` variable, which allows you to control which version of the module to use.

### Version Configuration

In your `terraform.tfvars`:

```hcl
# Use a specific release version (recommended for production)
release_version = "v1.0.0"
```

This variable is used in `main.tf` to construct the module source:

```hcl
module "eks_cluster" {
  source = "git::https://github.com/anysource-AI/anysource-infra.git//aws-helm/terraform-eks?ref=${var.release_version}"
  # ...
}
```

**Important**: Always use a specific version tag (e.g., "v1.0.0") for production deployments to ensure stability and predictable behavior.

### Available Versions

- **Stable releases**: Use semantic version tags like `v1.0.0`, `v1.1.0`
- **Latest development**: Use `main` for the latest features (not recommended for production)

### Private Git Repository with SSH

If you prefer SSH authentication, you can modify the module source in `main.tf`:

```hcl
source = "git::git@github.com:anysource-AI/anysource-infra.git//aws-helm/terraform-eks?ref=${var.release_version}"
```

## Outputs

After applying, you'll get important outputs:

- `cluster_name` - Name of the EKS cluster
- `cluster_endpoint` - EKS API endpoint
- `application_service_account_role_arn` - IAM role ARN for application IRSA
- `load_balancer_controller_role_arn` - IAM role ARN for ALB controller
- `bedrock_guardrail_arn` - Bedrock guardrail ARN
- `vpc_id` - VPC ID
- `database_endpoint` - RDS endpoint
- `redis_endpoint` - Redis endpoint

## Next Steps

After the infrastructure is deployed:

1. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region us-east-1
   ```

2. **Verify cluster access**:
   ```bash
   kubectl get nodes
   ```

3. **Deploy your application** using Helm or kubectl

## Comparison: All Deployment Modes

| Feature | MODE 1<br/>New VPC + New EKS | MODE 2<br/>Existing VPC + New EKS | MODE 3<br/>Existing VPC + Existing EKS |
|---------|----------------|---------------------|---------------------|
| **Use Case** | New deployment, full control | Integrate with existing network | Add app to existing cluster |
| **Creates VPC** | ✅ Yes | ❌ Uses existing | ❌ Uses existing |
| **Creates EKS Cluster** | ✅ Yes | ✅ Yes | ❌ No |
| **Creates Node Groups** | ✅ Yes | ✅ Yes | ❌ No |
| **Creates RDS** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Creates Redis** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Creates IRSA Roles** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Installs EKS Add-ons** | ✅ Yes | ✅ Yes | ❌ Already installed |
| **Best For** | Greenfield deployments | Existing network integration | Multi-tenant clusters, platform teams |

## Deployment Modes

The module supports three deployment modes:

1. **MODE 1** - New VPC + New EKS Cluster (Full Stack)
2. **MODE 2** - Existing VPC + New EKS Cluster  
3. **MODE 3** - Existing VPC + Existing EKS Cluster

See the sections above for detailed instructions on each mode.

## Support

For more information, see:
- Main module README: `/aws-helm/terraform-eks/README.md`
- Module variables documentation in the main README
- Terraform module documentation: https://www.terraform.io/docs/language/modules/index.html
