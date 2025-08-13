# AWS EKS Terraform Module

This Terraform module provisions an Amazon EKS (Elastic Kubernetes Service) cluster using the official AWS EKS Terraform module. It is designed for seamless integration with the Anysource Helm chart for production workloads.

## Features

- **EKS Cluster**: Creates an EKS cluster with configurable Kubernetes version
- **Managed Node Groups**: Configurable EKS managed node groups with auto-scaling
- **Security**: KMS encryption for Kubernetes secrets
- **IRSA Support**: IAM Roles for Service Accounts (IRSA) enabled
- **Add-ons**: Essential EKS add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI driver)
- **Flexible Networking**: Works with existing VPC and subnets (private/public)
- **Production Security**: Restrict API access, enable private endpoint, whitelist IPs, custom security group rules, encryption
- **Seamless Helm Integration**: Designed for use with Anysource Helm chart (see ../anysource-chart/README.md)

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0
3. **Existing VPC** with private subnets (and optionally public subnets)
4. **kubectl** for cluster access (optional)

## Quick Start

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
   region  = "us-west-2"
   account = "123456789012"
   vpc_id  = "vpc-12345678"
   # Optional: specify subnet IDs or let module auto-discover
   private_subnet_ids = ["subnet-12345", "subnet-67890"]
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
   aws eks update-kubeconfig --region us-west-2 --name <your-cluster-name>
   ```
7. **Deploy Anysource Helm chart** (see ../anysource-chart/README.md for AWS production values and secret setup)

## Configuration

### Required Variables

| Variable  | Description                      | Example          |
| --------- | -------------------------------- | ---------------- |
| `region`  | AWS region                       | `"us-west-2"`    |
| `account` | AWS Account ID                   | `"123456789012"` |
| `vpc_id`  | VPC ID where EKS will be created | `"vpc-12345678"` |

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
    disk_size = 20
  }
}
```

### Cluster Add-ons

Essential add-ons are enabled by default:

```hcl
cluster_addons = {
  coredns = { preserve = true }
  kube-proxy = { preserve = true }
  vpc-cni = { preserve = true }
  aws-ebs-csi-driver = { preserve = true }
}
```

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
```

**Public subnets**:

```
Type = "public"
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

## License

This module is part of the Anysource project and follows the same licensing terms.
