# Example: Using the ECS Terraform Module

This directory contains an example of how to use the ECS Terraform module to deploy a complete ECS cluster with all necessary infrastructure.

## Overview

This directory contains two deployment scenarios:

1. **New VPC + New ECS Cluster** (MODE 1 - Default): Deploy a complete ECS cluster with new VPC, RDS, Redis, and application infrastructure
2. **Existing VPC + New ECS Cluster** (MODE 2): Deploy a new ECS cluster in an existing VPC with RDS, Redis, and application infrastructure

## Files

All configuration files support both deployment modes:

- **`main.tf`** - Main Terraform configuration with MODE 1 and MODE 2 sections
- **`variables.tf`** - Variable definitions for all modes
- **`outputs.tf`** - Outputs for all modes
- **`terraform.tfvars.example`** - Example values with MODE 1 and MODE 2 sections
- **`.gitignore`** - Prevents committing sensitive files
- **`README.md`** - This file

**Note**: Each file contains both modes. Simply comment/uncomment the appropriate sections based on your deployment scenario.

## Switching Between Modes

All configuration files are designed to support both modes. To switch between them:

1. **In `terraform.tfvars`**: Comment/uncomment the MODE sections
2. **In `main.tf`**: Comment/uncomment the module blocks (only one module block should be active)

**Quick Reference:**

- **MODE 1 Active** (New VPC + New ECS): Default configuration, creates new VPC automatically
- **MODE 2 Active** (Existing VPC + New ECS): Uncomment existing VPC variables in tfvars, uncomment MODE 2 module in main.tf

## Usage

Choose one of the deployment modes below based on your needs:

### Mode 1: New VPC + New ECS Cluster (Full Stack)

Use this when deploying a complete new ECS cluster with all infrastructure.

#### 1. Copy the Example Files

```bash
# Create a new directory for your deployment
mkdir -p my-deployment
cd my-deployment

# Copy the example files
cp /path/to/aws-terraform-ecs/examples/main.tf .
cp /path/to/aws-terraform-ecs/examples/variables.tf .
cp /path/to/aws-terraform-ecs/examples/outputs.tf .
cp /path/to/aws-terraform-ecs/examples/terraform.tfvars.example terraform.tfvars
cp /path/to/aws-terraform-ecs/examples/.gitignore .
```

#### 2. Update Configuration

Edit `terraform.tfvars`:

- Set `release_version` to the desired module version (e.g., "v1.0.0", "v1.1.0")
- Update **required configuration**:
  - `region` - AWS region for deployment
  - `domain_name` - Your domain name for the application
  - `auth_client_id` and `auth_api_key` - Auth credentials (from Runlayer support)
- Optionally customize:
  - `ecr_repositories` - Use defaults or provide your own container images
  - `ssl_certificate_arn` - Provide existing ACM certificate or leave commented for auto-creation
- Ensure **MODE 2** section remains commented out
- Optionally enable monitoring in the OPTIONAL CONFIGURATION section

Edit `main.tf` to customize:

- `locals` block with your project name, environment, and AWS account ID
- Module source (use git URL with version tag)
- Ensure **MODE 1** module section is active (uncommented)
- Ensure **MODE 2** module section is commented out
- Optionally customize network security, database config, or service scaling in the module block

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

### Mode 2: Existing VPC + New ECS Cluster

Use this when you have an existing VPC and want to deploy a new ECS cluster within it.

#### Prerequisites

Before using this mode, ensure your existing VPC has:

1. **At least 3 private subnets** in different availability zones (for high availability)
2. **At least 3 public subnets** in different availability zones (for ALB)
3. **NAT Gateway** configured for private subnets (for container image pulls)
4. **Internet Gateway** attached to public subnets (for ALB)

#### 1. Copy the Example Files

```bash
# Create a new directory for your deployment
mkdir -p my-deployment
cd my-deployment

# Copy the example files
cp /path/to/aws-terraform-ecs/examples/main.tf .
cp /path/to/aws-terraform-ecs/examples/variables.tf .
cp /path/to/aws-terraform-ecs/examples/outputs.tf .
cp /path/to/aws-terraform-ecs/examples/terraform.tfvars.example terraform.tfvars
cp /path/to/aws-terraform-ecs/examples/.gitignore .
```

#### 2. Update Configuration

Edit `terraform.tfvars`:

- Set `release_version` to the desired module version (e.g., "v1.0.0", "v1.1.0")
- Update **required configuration**:
  - `region` - AWS region for deployment
  - `domain_name` - Your domain name for the application
  - `auth_client_id` and `auth_api_key` - Auth credentials (from Runlayer support)
- Uncomment **MODE 2** section and update with your values:
  - `vpc_id` - Your existing VPC ID
  - `private_subnet_ids` - List of private subnet IDs
  - `public_subnet_ids` - List of public subnet IDs
- Optionally customize:
  - `ecr_repositories` - Use defaults or provide your own container images
  - `ssl_certificate_arn` - Provide existing ACM certificate or leave commented for auto-creation
- Optionally enable monitoring in the OPTIONAL CONFIGURATION section

Edit `main.tf`:

- `locals` block with your project name, environment, and AWS account ID
- Module source (use git URL with version tag)
- Comment out **MODE 1** module section
- Uncomment **MODE 2** module section
- Optionally customize network security, database config, or service scaling in the module block

#### 3. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

#### What Gets Created

When using an existing VPC, the module creates:

✅ **ECS Cluster**: New Fargate cluster with auto-scaling  
✅ **Application Load Balancer**: ALB with SSL termination  
✅ **RDS Database**: Aurora PostgreSQL Serverless v2  
✅ **Redis Cache**: ElastiCache Redis  
✅ **Bedrock Guardrail**: AWS Bedrock guardrail for AI safety  
✅ **Secrets Manager**: Application secrets storage  
✅ **IAM Roles**: ECS task execution and task roles  
✅ **Security Groups**: For ALB, ECS tasks, RDS, and Redis

❌ **Does NOT create**: VPC, subnets, NAT Gateway, Internet Gateway

---

## Key Configuration Options

### Domain Configuration

All deployments require a domain name in `terraform.tfvars`:

```hcl
region      = "us-east-1"
domain_name = "runlayer.yourcompany.com"
```

### SSL Certificate

You can either:

1. **Use an existing ACM certificate** (recommended for production):

   ```hcl
   ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-certificate-id"
   ```

2. **Let the module create a new ACM certificate** (default):
   - Leave `ssl_certificate_arn` commented out in `terraform.tfvars`
   - Module will create and validate certificate automatically
   - Requires domain DNS to be pointed to AWS

### Network Security

Restrict ALB access to specific IP ranges in `main.tf`:

```hcl
module "ecs_cluster" {
  # ... other configuration ...

  alb_allowed_cidrs = [
    "203.0.113.0/24",    # Office IP range
    "198.51.100.0/24"    # VPN IP range
  ]
}
```

### Database Scaling

Customize Aurora Serverless v2 capacity in `main.tf`:

```hcl
module "ecs_cluster" {
  # ... other configuration ...

  database_config = {
    min_capacity     = 2   # Minimum ACU (1 ACU = ~2GB RAM)
    max_capacity     = 16  # Maximum ACU for scaling
    backup_retention = 7   # Days to keep backups
  }
}
```

### Application Scaling

Customize ECS service scaling in `main.tf`:

```hcl
module "ecs_cluster" {
  # ... other configuration ...

  services_configurations = {
    "backend" = {
      desired_count = 3     # Number of tasks to run
      max_capacity  = 20    # Maximum for auto-scaling
      cpu          = 4096   # 4 vCPU
      memory       = 8192   # 8 GB RAM
    }
    "frontend" = {
      desired_count = 3     # Number of tasks to run
      max_capacity  = 10    # Maximum for auto-scaling
      cpu          = 1024   # 1 vCPU
      memory       = 2048   # 2 GB RAM
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
module "ecs_cluster" {
  source = "git::https://github.com/anysource-AI/runlayer-infra.git//aws-terraform-ecs?ref=${var.release_version}"
  # ...
}
```

**Important**: Always use a specific version tag (e.g., "v1.0.0") for production deployments to ensure stability and predictable behavior.

### Available Versions

- **Stable releases**: Use semantic version tags like `v1.0.0`, `v1.1.0`

### Private Git Repository with SSH

If you prefer SSH authentication, you can modify the module source in `main.tf`:

```hcl
source = "git::git@github.com:anysource-AI/runlayer-infra.git//aws-terraform-ecs?ref=${var.release_version}"
```

## Outputs

After applying, you'll get important outputs:

- `application_url` - HTTPS URL to access your application
- `alb_dns_name` - DNS name of the ALB (for creating DNS records)
- `alb_zone_id` - Zone ID of the ALB (for Route53 alias records)
- `task_role_arn` - IAM role ARN for ECS tasks

## Next Steps

After the infrastructure is deployed:

1. **Access your application**:

   ```bash
   # Get the application URL
   terraform output application_url
   ```

2. **Verify services are running**:

   ```bash
   # Check ECS cluster
   aws ecs list-services --cluster anysource-production --region us-east-1

   # Check task health
   aws ecs describe-services --cluster anysource-production --services backend frontend --region us-east-1
   ```

3. **Check application logs**:

   - Backend logs: `/anysource-backend-logs-production` in CloudWatch
   - Frontend logs: `/anysource-frontend-logs-production` in CloudWatch
   - Prestart logs: `/anysource-prestart-logs-production` in CloudWatch (database migrations)

4. **Set up DNS** (if not using Route53):
   - Get ALB DNS name: `terraform output alb_dns_name`
   - Create a CNAME record in your DNS provider pointing your domain to the ALB DNS name

   If you manage DNS in Route53, set `enable_acm_dns_validation = true` and provide `hosted_zone_name` so the module can both complete ACM DNS validation and create the ALIAS record automatically.

## Comparison: Deployment Modes

| Feature                     | MODE 1<br/>New VPC + New ECS | MODE 2<br/>Existing VPC + New ECS |
| --------------------------- | ---------------------------- | --------------------------------- |
| **Use Case**                | New deployment, full control | Integrate with existing network   |
| **Creates VPC**             | ✅ Yes                       | ❌ Uses existing                  |
| **Creates ECS Cluster**     | ✅ Yes                       | ✅ Yes                            |
| **Creates ALB**             | ✅ Yes                       | ✅ Yes                            |
| **Creates RDS**             | ✅ Yes                       | ✅ Yes                            |
| **Creates Redis**           | ✅ Yes                       | ✅ Yes                            |
| **Creates IAM Roles**       | ✅ Yes                       | ✅ Yes                            |
| **Creates Security Groups** | ✅ Yes                       | ✅ Yes                            |
| **Best For**                | Greenfield deployments       | Existing network integration      |

## Backend Configuration

Use S3 backend for secure state storage:

```bash
# 1. Set up backend configuration
cp examples/backend.config.example backend.config
nano backend.config  # Configure your S3 bucket details

# 2. Initialize with backend
terraform init -backend-config=backend.config

# 3. Deploy
terraform plan
terraform apply
```

**Best Practices:**

- Enable S3 bucket versioning for state history
- Enable encryption at rest for the S3 bucket
- Use DynamoDB for state locking to prevent concurrent modifications
- Restrict access to the state bucket using IAM policies

## Cost Optimization

- Use appropriate instance sizing based on workload requirements
- Enable auto-scaling to match demand and avoid over-provisioning
- Use Aurora Reserved Capacity for predictable workloads
- Set up cost alerts and budgets in AWS Billing
- Monitor CloudWatch metrics to identify optimization opportunities
- Review and adjust scaling thresholds based on actual usage patterns

## Troubleshooting

### Common Issues

**Certificate validation fails:**

- Ensure domain DNS is configured correctly
- Check ACM certificate status in AWS Console
- Verify certificate is in the same region as your ALB

**ECS tasks not starting:**

- Check ECS service events in AWS Console
- Review CloudWatch logs:
  - `/anysource-backend-logs-[env]`
  - `/anysource-frontend-logs-[env]`
  - `/anysource-prestart-logs-[env]` (for database migration issues)
- Verify secrets are configured in Secrets Manager
- Check security group rules allow necessary traffic

**Database connection issues:**

- Verify security groups allow ECS tasks to connect to RDS
- Check database endpoint in RDS console
- Review prestart container logs for migration errors

**Networking issues:**

- Ensure NAT Gateway is properly configured in private subnets
- Verify Internet Gateway is attached to public subnets
- Check route tables are correctly associated

### Getting Help

- **Logs**: CloudWatch log groups for each service
- **Events**: ECS service events in AWS Console
- **Metrics**: CloudWatch dashboards for ECS and RDS
- **Validation**: Run `terraform validate` before applying
- **Planning**: Always run `terraform plan` to preview changes

## Security Best Practices

1. **Use private subnets** for database and cache resources
2. **Restrict ALB access** with IP allowlists in production
3. **Enable deletion protection** on RDS in production (`deletion_protection = true`)
4. **Rotate secrets regularly** in AWS Secrets Manager
5. **Use S3 backend** with encryption and versioning for Terraform state
6. **Monitor with CloudTrail** and enable VPC Flow Logs
7. **Use least-privilege IAM roles** for ECS tasks

## Monitoring & Observability

### CloudWatch Integration

The deployment includes comprehensive monitoring:

- **Log Groups**:

  - `anysource-backend-logs-[environment]` - Backend application logs
  - `anysource-frontend-logs-[environment]` - Frontend application logs
  - `anysource-prestart-logs-[environment]` - Database migration logs
  - `anysource-worker-logs-[environment]` - Background worker logs (if enabled)

- **Metrics**: CPU, memory, task count, ALB metrics
- **Alarms**: Service health and resource saturation (when `enable_monitoring = true`)
- **Dashboards**: Built-in ECS service dashboards in CloudWatch

### Sentry Integration (Optional)

Enable error tracking with Sentry in `terraform.tfvars`:

```hcl
enable_monitoring = true
sentry_dsn       = "https://your-sentry-dsn@sentry.io/project-id"
```

## Architecture Features

- **High Availability**: Multi-AZ deployment with auto-scaling ECS tasks
- **Security**: Private database subnets, security groups, SSL/TLS termination
- **Scalability**: Auto-scaling based on CPU/memory metrics
- **Reliability**: Automated backups, health checks, load balancing
- **Monitoring**: CloudWatch integration, ECS service events, alarms, dashboards
- **Secrets Management**: AWS Secrets Manager integration for sensitive data
- **Container Orchestration**: Multi-container tasks with dependency management (prestart + main backend)

## Support

For more information, see:

- Main module README: `/aws-terraform-ecs/README.md`
- Module variables documentation in the main README
- Configuration example: `/aws-terraform-ecs/examples/terraform.tfvars.example`
- Terraform module documentation: https://www.terraform.io/docs/language/modules/index.html
