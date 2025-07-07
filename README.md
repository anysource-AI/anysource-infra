# Anysource Infrastructure

Terraform configurations for deploying Anysource on AWS with production-ready defaults.

## Quick Start

### Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- Domain name you control

### Deploy

1. **Configure**:
   ```bash
   cp minimal.tfvars.example production.tfvars
   # Edit only these 5 required values:
   ```
   ```hcl
   environment = "production"
   region      = "us-east-1"
   domain_name = "ai.yourcompany.com"
   account     = 123456789012
   suffix_secret_hash = "PROD2024"
   ```

2. **Deploy**:
   ```bash
   terraform init
   terraform plan -var-file="production.tfvars"
   terraform apply -var-file="production.tfvars"
   ```

3. **Configure Secrets**:
   ```bash
   # Update in AWS Secrets Manager after deployment
   aws secretsmanager update-secret \
     --secret-id "anysource-production-app-secrets-${suffix_secret_hash}" \
     --secret-string '{"SECRET_KEY":"your-secret-key","FIRST_SUPERUSER":"admin@company.com","FIRST_SUPERUSER_PASSWORD":"your-password"}'
   ```

4. **Verify**:
   ```bash
   curl https://your-domain.com/api/v1/utils/health-check/
   ```

## What Gets Created

- **VPC**: Multi-AZ network with public/private subnets
- **Database**: Aurora PostgreSQL with automated backups
- **Cache**: Redis ElastiCache
- **Load Balancer**: ALB with automatic SSL certificate
- **Compute**: ECS Fargate services with auto-scaling
- **Security**: Security groups, IAM roles, secrets management

## Configuration

For **minimal deployment** (recommended), use the 5 values above.

For **enterprise customization**, copy `enterprise.tfvars.example` instead and customize:
- Database sizing and backup retention
- Network security (private ALB, IP restrictions)
- Scaling parameters and resource limits
- Custom SSL certificates

## Common Operations

### Update Application
```bash
# Force deployment of latest images
aws ecs update-service --cluster anysource-production --service backend --force-new-deployment
aws ecs update-service --cluster anysource-production --service frontend --force-new-deployment
```

### Scale Resources
```bash
# Edit production.tfvars, then:
terraform apply -var-file="production.tfvars"
```

### Check Status
```bash
# Get important endpoints
terraform output alb_dns_name
terraform output backend_ecr_url
terraform output frontend_ecr_url
```

## Troubleshooting

**Certificate issues**: Check domain DNS configuration
**ECS tasks not starting**: Check CloudWatch logs at `/aws/ecs/anysource-production`
**Database connection**: Verify secrets are configured correctly

## Architecture

```
Internet → ALB (Public) → ECS Fargate (Private) → RDS + Redis (Private)
```

**Default Resources**:
- 2 backend + 2 frontend containers (auto-scale to 10)
- Aurora PostgreSQL (2-16 ACUs, 7-day backups)
- Redis cluster
- Application Load Balancer with SSL

For detailed configuration options, see `enterprise.tfvars.example`.
