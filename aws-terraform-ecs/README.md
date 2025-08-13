# Anysource Infrastructure

Deploy Anysource on AWS with Terraform. Choose from simple HTTP deployments to enterprise-grade HTTPS configurations.

## Quick Start

1. **Choose your deployment type:**

   - [**No Domain**](examples/no_domain.tfvars) - Simple HTTP deployment (development/testing)
   - [**Custom Domain**](examples/custom_domain.tfvars) - HTTPS with your domain (production)
   - [**Custom Deployment**](examples/custom_deployment.tfvars) - Full enterprise customization

2. **Copy and configure:**

   ```bash
   # Choose one based on your needs
   cp examples/no_domain.tfvars terraform.tfvars
   cp examples/custom_domain.tfvars terraform.tfvars
   cp examples/custom_deployment.tfvars terraform.tfvars

   # Edit the required values
   nano terraform.tfvars
   ```

3. **Deploy:**

   ```bash
   # For development (local state)
   terraform init -backend=false
   terraform apply

   # For production (S3 backend) - see Backend Configuration below
   cp examples/backend.tfvars backend.tfvars
   terraform init -backend-config=backend.tfvars
   terraform apply
   ```

## Configuration Examples

### No Domain Deployment (HTTP Only)

Perfect for development and testing environments.

```hcl
environment     = "development"
region          = "us-east-1"
hf_token        = "hf_your_token_here"

ecr_repositories = {
  backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
}
```

**Access:** Via ALB DNS name on HTTP (see `application_url` output)

### Custom Domain Deployment (HTTPS)

Production-ready with automatic SSL certificates.

```hcl
environment     = "production"
region          = "us-east-1"
domain_name     = "mcp.yourcompany.com"  # Your domain
hf_token        = "hf_your_token_here"

ecr_repositories = {
  backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
}
```

**Access:** https://mcp.yourcompany.com

- For custom domain deployments, you **must** provide an ACM certificate ARN via the `certificate_arn` variable in your tfvars file. This certificate must cover your chosen domain (e.g., mcp.yourcompany.com). See the `examples/custom_domain.tfvars` for details.

## Backend Configuration

For production deployments, use S3 backend for state storage:

```bash
# 1. Set up backend configuration
cp examples/backend.tfvars backend.tfvars
nano backend.tfvars  # Configure your S3 bucket

# 2. Initialize with backend
terraform init -backend-config=backend.tfvars

# 3. Deploy
terraform apply
```

## What Gets Deployed

```
┌─────────────┐
│ Application │ ← https://your-domain.com (or ALB DNS)
│ Load Balancer│
└──────┬──────┘
       │
┌──────▼──────┐
│ ECS Fargate │ Backend + Frontend containers
│ Auto-scaling│ (Backend includes prestart container)
└─────┬───────┘
      │
┌─────▼─────┐ ┌────────────┐
│PostgreSQL │ │   Redis    │ Private subnets
│ Database  │ │   Cache    │
└───────────┘ └────────────┘
```

**Infrastructure includes:**

- **Network:** VPC with public/private subnets across 3 AZs
- **Compute:** ECS Fargate with auto-scaling (2-10 instances)
- **Database:** Aurora PostgreSQL with automated backups
- **Cache:** Redis ElastiCache cluster
- **Security:** ALB with SSL termination, security groups, secrets management
- **DNS:** Optional Route53 integration or external DNS management

**Container Architecture:**

- **Backend Service:** Multi-container task with dependency management
  - **Prestart Container:** Handles database migrations and initial data setup
  - **Main Backend Container:** FastAPI application (starts after prestart completes)
- **Frontend Service:** Single container serving the React application

## Required Configuration

All deployments need these values:

| Variable           | Description                                                 | Example                      |
| ------------------ | ----------------------------------------------------------- | ---------------------------- |
| `environment`      | Environment name                                            | `"production"`               |
| `region`           | AWS region                                                  | `"us-east-1"`                |
| `hf_token`         | HuggingFace token                                           | `"hf_your_token"`            |
| `auth_domain`      | Auth tenant domain (will be provided by Anysource support)  | `"your-tenant.us.auth0.com"` |
| `auth_client_id`   | Auth client ID (will be provided by Anysource support)      | `"your-auth-client-id"`      |
| `ecr_repositories` | Container image URIs                                        | See examples                 |

## Optional Configuration

### Security Restrictions

```hcl
alb_allowed_cidrs = [
  "203.0.113.0/24",    # Office IP range
  "198.51.100.0/24"    # VPN IP range
]
```

### Database Scaling

```hcl
database_config = {
  min_capacity     = 8      # Higher for production
  max_capacity     = 64     # Scale as needed
  backup_retention = 30     # Days to keep backups
}
```

### Application Scaling

```hcl
services_configurations = {
  "backend" = {
    desired_count = 4     # Production instances
    max_capacity  = 20    # Maximum scaling
    cpu          = 2048   # 2 vCPU
    memory       = 4096   # 4 GB RAM
  }
}
```

## Outputs

After deployment, you'll get:

| Output              | Description                    |
| ------------------- | ------------------------------ |
| `application_url`   | Primary application URL        |
| `alb_dns_name`      | Load balancer DNS name         |
| `database_endpoint` | PostgreSQL endpoint (internal) |
| `redis_endpoint`    | Redis endpoint (internal)      |

## Deployment Types

### Development

- HTTP-only access
- Minimal resources
- Local Terraform state
- Cost-optimized

### Production

- HTTPS with SSL certificates
- Auto-scaling enabled
- S3 backend for state
- High availability

### Enterprise

- Network security restrictions
- Advanced scaling configuration
- Multiple environments
- Custom SSL certificates

## Maintenance

### Update Application

```bash
# Images auto-update from public ECR
# Force service refresh:
aws ecs update-service --cluster anysource-[env] --service backend --force-new-deployment
aws ecs update-service --cluster anysource-[env] --service frontend --force-new-deployment
```

### Scale Resources

```bash
# Edit terraform.tfvars with new settings
terraform plan
terraform apply
```

## Troubleshooting

### Common Issues

**Certificate validation fails:**

- Ensure domain DNS points to AWS
- Check ACM certificate status in AWS Console

**ECS tasks not starting:**

- Check ECS service events
- Verify secrets are configured
- Review CloudWatch logs: `/aws/ecs/anysource-[env]`
- **Backend-specific:** Check prestart container logs for migration failures

**Database migration issues:**

- Check prestart container logs: `prestart-logs-[env]` in CloudWatch
- Verify database connectivity from ECS tasks
- Ensure database is accessible before backend deployment
- Review alembic migration scripts for conflicts

**Connection issues:**

- Verify security group rules
- Check subnet configurations
- Validate secret values

### Getting Help

- **Logs:** CloudWatch `/aws/ecs/anysource-[env]` (main containers)
- **Migration Logs:** CloudWatch `prestart-logs-[env]` (database setup)
- **Events:** ECS service events in AWS Console
- **Validation:** `terraform validate`
- **Planning:** `terraform plan` before applying changes

## Cost Optimization

### Development

```hcl
database_config = { min_capacity = 0.5, max_capacity = 2 }
services_configurations = {
  "backend"  = { desired_count = 1 }
  "frontend" = { desired_count = 1 }
}
```

### Production

- Use Aurora Reserved Instances
- Set up billing alerts
- Monitor CloudWatch metrics for optimization

## Security Best Practices

1. **Use private subnets** for database and cache
2. **Restrict ALB access** with IP allowlists
3. **Enable state encryption** in S3 backend
4. **Regularly rotate secrets** in AWS Secrets Manager
5. **Monitor with CloudTrail** and GuardDuty
6. **Use least-privilege IAM** roles

## ECS Monitoring & Observability

Anysource ECS deployments include robust monitoring and observability features:

- **CloudWatch Logs:** All ECS containers (backend, frontend, prestart) stream logs to CloudWatch. Access logs in the AWS Console under `/aws/ecs/anysource-[env]` for main containers and `prestart-logs-[env]` for migration/setup.
- **CloudWatch Metrics:** ECS service metrics (CPU, memory, task count, health checks) are available in CloudWatch. Use these for auto-scaling, troubleshooting, and performance optimization.
- **Alarms & Alerts:** Default CloudWatch alarms notify on service health, resource saturation, and failures. Customize thresholds and notification channels as needed.
- **Dashboards:** AWS Console provides built-in dashboards for ECS services. For advanced visualization, integrate with Grafana or custom dashboards.
- **Troubleshooting:** Use CloudWatch logs and ECS service events to diagnose issues. Common problems (task failures, migration errors) are logged for rapid root cause analysis.
- **Audit & Compliance:** All activity is logged for audit and compliance tracking. Log retention and export are configurable.

For full details, best practices, and advanced monitoring options, see [Monitoring & Observability Documentation](../../docs/infrastructure/monitoring.mdx).

## Architecture Features

- **High Availability:** Multi-AZ deployment with auto-scaling
- **Security:** Private database subnets, security groups, SSL/TLS
- **Scalability:** Auto-scaling based on CPU/memory metrics
- **Reliability:** Automated backups, health checks, load balancing
- **Monitoring:** CloudWatch integration, ECS service events, alarms, dashboards
- **Secrets Management:** AWS Secrets Manager integration
