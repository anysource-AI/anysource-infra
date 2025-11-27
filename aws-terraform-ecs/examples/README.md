# Example: Using the ECS Terraform Module

Deploy an ECS cluster with two modes:

1. **MODE 1** (Default): New VPC + New ECS Cluster
2. **MODE 2**: Existing VPC + New ECS Cluster

## Quick Start

### MODE 1: New VPC + New ECS Cluster

```bash
# 1. Copy files
mkdir my-deployment && cd my-deployment
cp /path/to/examples/{main.tf,variables.tf,outputs.tf,.gitignore} .
cp /path/to/examples/terraform.tfvars.example terraform.tfvars

# 2. Configure terraform.tfvars
# - Set release_version (e.g., "v1.0.0")
# - Set region, domain_name, auth_client_id, auth_api_key
# - Keep MODE 2 section commented

# 3. Configure main.tf
# - Update locals (project name, environment, AWS account ID)
# - Ensure MODE 1 module is active, MODE 2 is commented

# 4. Deploy
terraform init
terraform plan
terraform apply
```

### MODE 2: Existing VPC + New ECS Cluster

**Prerequisites:**
- 3+ private subnets in different AZs
- 3+ public subnets in different AZs
- NAT Gateway for private subnets
- Internet Gateway for public subnets

```bash
# 1. Copy files (same as MODE 1)
mkdir my-deployment && cd my-deployment
cp /path/to/examples/{main.tf,variables.tf,outputs.tf,.gitignore} .
cp /path/to/examples/terraform.tfvars.example terraform.tfvars

# 2. Configure terraform.tfvars
# - Set release_version, region, domain_name, auth credentials
# - Uncomment MODE 2 section
# - Set vpc_id, private_subnet_ids, public_subnet_ids

# 3. Configure main.tf
# - Update locals
# - Comment MODE 1 module, uncomment MODE 2 module

# 4. Deploy
terraform init
terraform plan
terraform apply
```

## Configuration

### Network Security

```hcl
alb_allowed_cidrs = ["203.0.113.0/24"]  # IP allowlist
```

### Dual ALB (Split-Horizon DNS)

```hcl
enable_dual_alb = true
# Creates public + internal ALB with split-horizon DNS
```

### VPC Peering

```hcl
vpc_peering_connections = {
  "customer-vpc" = {
    peering_connection_id = "pcx-0abc123def456"
    peer_vpc_cidr         = "172.16.0.0/16"
    peer_owner_id         = "123456789012"  # Required
  }
}
```

## Outputs

- `application_url` - HTTPS URL
- `alb_dns_name` - ALB DNS name
- `task_role_arn` - ECS task IAM role

## Troubleshooting

**Certificate validation fails:**
- Check ACM certificate status in AWS Console

**ECS tasks not starting:**
- Check CloudWatch logs: `/anysource-{backend,frontend,prestart}-logs-[env]`
- Verify Secrets Manager secrets exist

**Database connection issues:**
- Check security groups allow ECS → RDS traffic
- Review prestart logs for migration errors
