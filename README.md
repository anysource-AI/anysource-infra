# Anysource Enterprise Infrastructure

This directory contains Terraform configurations for deploying Anysource on AWS infrastructure. It provides production-ready infrastructure with smart defaults that can be customized for enterprise needs.

## Overview

The Terraform configuration creates:

- **VPC**: Multi-AZ network with public/private subnets
- **Database**: Aurora PostgreSQL with automated backups
- **Cache**: Redis ElastiCache cluster
- **Load Balancer**: Application Load Balancer with SSL/TLS termination
- **Compute**: ECS Fargate services with auto-scaling
- **Security**: Security groups, IAM roles, and secrets management
- **DNS**: Optional Route53 integration or bring-your-own certificate

## Quick Start

### 1. Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Domain name you control (for SSL certificate)

### 2. Minimal Deployment (Recommended)

For the fastest deployment with production-ready defaults:

```bash
# Copy minimal configuration
cp minimal.tfvars.example production.tfvars

# Edit only these required values:
nano production.tfvars
```

**Required Configuration** (only 5 values):

```hcl
environment = "production"
region      = "us-east-1"
domain_name = "ai.yourcompany.com"  # Your domain
account     = 123456789012          # Your AWS account ID
suffix_secret_hash = "PROD2024"     # Unique identifier
```

**Deploy:**

```bash
terraform init
terraform plan
terraform apply
```

### 3. Enterprise Deployment (Full Control)

For extensive customization options:

```bash
# Copy enterprise configuration
cp enterprise.tfvars.example production.tfvars

# Customize all settings as needed
nano production.tfvars
```

## Configuration Options

### Smart Defaults (Minimal Configuration)

When using minimal configuration, you get these production-ready defaults:

| Component     | Default Configuration                                             |
| ------------- | ----------------------------------------------------------------- |
| **Database**  | Aurora PostgreSQL 16.6, 2-16 ACUs, private subnets, 7-day backups |
| **Security**  | Public ALB, private database/cache, internet access allowed       |
| **SSL**       | Automatic ACM certificate creation and validation                 |
| **Scaling**   | 2 backend + 2 frontend containers, auto-scale to 10 max           |
| **Resources** | Backend: 512 CPU/1024 MB, Frontend: 512 CPU/1024 MB               |
| **Network**   | 3-AZ VPC, /16 CIDR, public/private subnets                        |

### Enterprise Customization Options

| Category     | Customizable Options                                         |
| ------------ | ------------------------------------------------------------ |
| **Database** | Engine version, capacity, backup retention, subnet placement |
| **Security** | Private ALB, IP restrictions, certificate management         |
| **Scaling**  | Instance counts, CPU/memory, auto-scaling thresholds         |
| **Network**  | Custom CIDR, availability zones, subnet configurations       |
| **Services** | Additional S3 buckets, Lambda functions, monitoring          |

## Architecture

```
Internet Gateway
       │
   ┌───▼───┐
   │  ALB  │ (Public subnets)
   └───┬───┘
       │
┌──────▼──────┐
│ ECS Fargate │ (Private subnets)
│ Backend/Frontend │
└─────┬───┬───┘
      │   │
  ┌───▼┐ ┌▼────┐
  │RDS │ │Redis│ (Private subnets)
  └────┘ └─────┘
```

## Environment Variables and Secrets

The infrastructure automatically creates AWS Secrets Manager entries for:

- Database credentials (auto-generated)
- Application secrets (you provide)
- API keys and JWT secrets

**Required Secrets** (configure in AWS Secrets Manager after deployment):

- `SECRET_KEY`: Application secret key
- `FIRST_SUPERUSER`: Initial admin email
- `FIRST_SUPERUSER_PASSWORD`: Initial admin password

## Deployment Process

### 1. Plan and Review

```bash
terraform plan -var-file="production.tfvars"
```

### 2. Deploy Infrastructure

```bash
terraform apply -var-file="production.tfvars"
```

### 3. Configure Secrets

```bash
# Update secrets in AWS Console or CLI
aws secretsmanager update-secret \
  --secret-id "anysource-production-app-secrets-${suffix_secret_hash}" \
  --secret-string '{"SECRET_KEY":"your-secret-key","FIRST_SUPERUSER":"admin@company.com"}'
```

### 4. Verify Deployment

```bash
# Check ALB endpoint
terraform output alb_dns_name

# Check application health
curl https://your-domain.com/api/v1/utils/health-check/
```

## Common Configurations

### Private Network (Enterprise Security)

```hcl
alb_access_type = "private"
alb_allowed_cidrs = ["10.0.0.0/8", "172.16.0.0/12"]  # Corporate networks
database_config = {
  publicly_accessible = false
  subnet_type = "private"
}
```

### High Availability Production

```hcl
database_config = {
  min_capacity = 8
  max_capacity = 64
  backup_retention = 30
}

services_configurations = {
  "backend" = {
    desired_count = 4
    max_capacity = 20
    cpu = 2048
    memory = 4096
  }
}
```

### Using Existing SSL Certificate

```hcl
ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
create_route53_records = false  # Manage DNS externally
```

## Outputs

After deployment, Terraform provides these outputs:

| Output              | Description                     |
| ------------------- | ------------------------------- |
| `alb_dns_name`      | Load balancer DNS name          |
| `backend_ecr_url`   | Backend Docker image URL        |
| `frontend_ecr_url`  | Frontend Docker image URL       |
| `database_endpoint` | RDS endpoint (internal)         |
| `redis_endpoint`    | ElastiCache endpoint (internal) |

## Maintenance

### Updating Application Images

```bash
# Images are pulled automatically from public ECR
# Force ECS service update to pull latest:
aws ecs update-service --cluster anysource-production --service backend --force-new-deployment
aws ecs update-service --cluster anysource-production --service frontend --force-new-deployment
```

### Scaling Resources

```bash
# Update production.tfvars with new capacity
# Apply changes:
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars"
```

### Backup and Recovery

- Database backups are automated (configurable retention)
- Point-in-time recovery available for Aurora
- Infrastructure state is stored in Terraform state

## Troubleshooting

### Common Issues

**1. Certificate Validation Fails**

- Ensure domain DNS is properly configured
- Check if domain is publicly resolvable
- Verify ACM certificate status in AWS Console

**2. ECS Tasks Not Starting**

- Check ECS service events in AWS Console
- Verify secrets are properly configured
- Check CloudWatch logs for container errors

**3. Database Connection Issues**

- Verify security group rules
- Check if database is in correct subnets
- Ensure secrets contain valid database credentials

### Getting Help

- Check CloudWatch logs: `/aws/ecs/anysource-production`
- Review ECS service events in AWS Console
- Validate Terraform configuration: `terraform validate`
- Check AWS resource status in AWS Console

## Cost Optimization

### Development/Staging

```hcl
database_config = {
  min_capacity = 0.5  # Minimum for Aurora Serverless
  max_capacity = 2
}

services_configurations = {
  "backend" = { desired_count = 1 }
  "frontend" = { desired_count = 1 }
}
```

### Production

- Use Aurora Reserved Instances for cost savings
- Enable detailed monitoring for optimization insights
- Set up billing alerts for cost control

## Security Best Practices

1. **Use private subnets** for database and cache
2. **Restrict ALB access** to corporate IP ranges when possible
3. **Enable CloudTrail** for audit logging
4. **Use least-privilege IAM** roles and policies
5. **Regularly rotate secrets** in AWS Secrets Manager
6. **Enable GuardDuty** for threat detection
7. **Use WAF** for additional web application protection

## License

This infrastructure configuration is provided for enterprise customers under the Anysource Enterprise License Agreement.
