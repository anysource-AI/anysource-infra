# Runlayer ECS Infrastructure

Deploy Runlayer on AWS ECS using Terraform. This infrastructure supports development to enterprise-grade production deployments with automated scaling, managed databases, and SSL certificates.

## Quick Start

1. **Copy and configure:**

   ```bash
   # Copy the example configuration
   cp examples/terraform.tfvars.example terraform.tfvars

   # Edit the required values
   nano terraform.tfvars
   ```

2. **Deploy:**

   ```bash
   # For development (local state)
   terraform init -backend=false
   terraform plan
   terraform apply

   # For production (S3 backend) - see Backend Configuration below
   cp examples/backend.config.example backend.config
   # Edit backend.config with your S3 bucket details
   terraform init -backend-config=backend.config
   terraform plan
   terraform apply
   ```

## Configuration Examples

### Standard Deployment (HTTPS)

Production-ready with SSL termination via AWS Certificate Manager (ACM).

```hcl
environment = "production"
region      = "us-east-1"
domain_name = "mcp.yourcompany.com"  # Your domain
```

**Access:** https://mcp.yourcompany.com

Provide an ACM certificate ARN via `ssl_certificate_arn` (in the same AWS region as the ALB). The certificate must cover your domain (e.g., mcp.yourcompany.com). See `examples/terraform.tfvars.example` for details.

## Backend Configuration

For production deployments, use S3 backend for state storage:

```bash
# 1. Set up backend configuration
cp examples/backend.config.example backend.config
nano backend.config  # Configure your S3 bucket

# 2. Initialize with backend
terraform init -backend-config=backend.config

# 3. Deploy
terraform plan
terraform apply
```

## What Gets Deployed

```
┌─────────────┐
│ Application │ ← https://your-domain.com
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
- **DNS:** Route53 integration or external DNS management

**Container Architecture:**

- **Backend Service:** Multi-container task with dependency management
  - **Prestart Container:** Handles database migrations and initial data setup
  - **Main Backend Container:** FastAPI application (starts after prestart completes)
- **Frontend Service:** Single container serving the React application
- **Sentry Relay Service:** Local telemetry processing for privacy compliance (**optional** - deployed when credentials are available)

## Sentry Relay Configuration (Optional)

Sentry Relay processes telemetry data within your infrastructure before forwarding to Sentry SaaS. This ensures customer data stays within your VPC for better privacy and compliance.

```
┌─────────┐     telemetry     ┌────────────┐     filtered     ┌─────────────┐
│ Backend │ ─────────────────>│   Relay    │ ───────────────>│ Sentry SaaS │
└─────────┘   (in your VPC)   └────────────┘   (internet)     └─────────────┘
```

**Benefits:** Privacy compliance, data residency, PII filtering, local buffering.

### Graceful Degradation

**Relay is optional.** Deployments work without Sentry credentials:

- **With credentials:** Relay is deployed, telemetry routed through your VPC
- **Without credentials:** Relay is skipped, backend logs "Sentry initialization skipped", deployment succeeds

Credentials are automatically fetched from WorkOS Vault during `terraform plan/apply`. If not found, deployment proceeds without Sentry.

### Setup (Optional)

To enable Sentry telemetry, contact Runlayer support to provision credentials in your WorkOS Vault:

**Secret Name:** `runlayer-sentry-credentials`  
**Secret Value (JSON):**

```json
{
  "public_key": "...",
  "secret_key": "...",
  "id": "...",
  "sentry_dsn": "https://..."
}
```

Terraform automatically:

1. Fetches credentials from WorkOS Vault (via `vault-fetch-relay.sh`)
2. Deploys Relay resources if credentials are valid
3. Stores credentials in AWS Secrets Manager
4. Configures backend to route telemetry through Relay

### Explicit Disable (Optional)

To disable Sentry Relay even when credentials are available:

```hcl
# In terraform.tfvars
sentry_relay_enabled = false  # Default: true
```

**Use cases:**

- Debugging: Temporarily disable telemetry
- Cost optimization: Reduce costs in non-production environments
- Testing: Deploy without telemetry

For detailed setup and monitoring, see `runbooks/testing-sentry-relay-locally.md`.

## Required Configuration

All deployments need these values:

| Variable           | Description                                           | Example                 |
| ------------------ | ----------------------------------------------------- | ----------------------- |
| `account`        | AWS account ID                                        | `"123456789012"`        |
| `region`         | AWS region                                            | `"us-east-1"`           |
| `domain_name`    | Custom domain for HTTPS access                        | `"mcp.yourcompany.com"` |
| `auth_client_id` | Auth client ID (will be provided by Runlayer support) | `"your-auth-client-id"` |
| `auth_api_key`   | Auth API key (will be provided by Runlayer support)   | `"your-auth-api-key"`   |

## Optional Configuration

### Runlayer ToolGuard (GPU-based ML Security Scanning)

Deploy the Runlayer ToolGuard Flask server on GPU instances for ML-based tool security scanning:

```hcl
enable_runlayer_tool_guard        = true
runlayer_tool_guard_desired_count = 1     # Number of instances
```

**Key Features:**
- **GPU-Powered**: High performance security scanners that target ~50ms latency
- **Cost-Effective**: Fractional GPU reduces costs compared to full GPU instances
- **Internal Service**: Uses ECS Service Connect for secure internal communication

### Using an Existing VPC

By default, a new VPC with public and private subnets will be created. If you want to use an existing VPC instead:

```hcl
# All three variables must be provided together
existing_vpc_id             = "vpc-xxxxx"
existing_private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
existing_public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb", "subnet-ccccc"]
```

**Requirements:**

- At least 3 subnets in different availability zones (for high availability)
- Private subnets must have internet access via NAT Gateway (for container image pulls)
- Public subnets must have internet gateway attached (for ALB)

**Note:** If not using an existing VPC, leave these variables unset or set to `null` and a new VPC will be created automatically.

### Security Restrictions

#### ALB Security Group IP Restrictions

Restrict access at the security group level (allows traffic to reach ALB):

```hcl
alb_allowed_cidrs = [
  "203.0.113.0/24",    # Office IP range
  "198.51.100.0/24"    # VPN IP range
]
```

#### WAF IP Allowlisting

For stricter security, use WAF to block requests from non-allowlisted IPs before they reach your application:

```hcl
waf_enable_ip_allowlisting = true
waf_allowlist_ipv4_cidrs = [
  "203.0.113.0/24",      # Office network
  "198.51.100.42/32",    # Specific IP address
]
```

**Key differences:**

- **Security Group (`alb_allowed_cidrs`):** Network-level filtering, allows traffic to reach ALB
- **WAF (`waf_allowlist_ipv4_cidrs`):** Application-level filtering with logging and metrics, blocks requests at ALB

**Best practice:** Use WAF allowlisting for production environments requiring audit trails and detailed request blocking metrics. WAF provides CloudWatch metrics and sampled request logs for security monitoring.

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

### ACM DNS Validation (Optional)

Set `enable_acm_dns_validation = true` to have Terraform create the AWS ACM validation records automatically in Route53. When this is enabled:

- `domain_name` must match the certificate’s fully qualified domain (e.g., `ecs.prod.example.com`).
- Set `hosted_zone_name` to the Route53 hosted zone that exists in this AWS account (required whenever ACM DNS validation is enabled; often an apex like `prod.example.com` even if the certificate is for `ecs.prod.example.com`).

Leave `enable_acm_dns_validation` as `false` if you prefer to validate ACM certificates manually or are using DNS outside of Route53.

### Route53 Alias Records (Automatic with ACM Validation)

When `enable_acm_dns_validation = true`, this module also creates an ALIAS `A` record in the specified Route53 hosted zone pointing your domain to the ALB. Provide `hosted_zone_name` so the module can look up the correct zone. Leave ACM DNS validation disabled to keep managing DNS externally.


## Secrets Management

This deployment creates the following secrets in AWS Secrets Manager:

| Secret                 | Description                       | Required |
| ---------------------- | --------------------------------- | -------- |
| `SECRET_KEY`           | JWT secret key for authentication | ✓        |
| `MASTER_SALT`          | Master salt for encryption        | ✓        |
| `AUTH_API_KEY`         | Authentication API key            | ✓        |
| `PLATFORM_DB_PASSWORD` | PostgreSQL database password      | ✓        |

**Note:** The `SECRET_KEY`, `MASTER_SALT`, and `PLATFORM_DB_PASSWORD` are automatically generated during deployment. The `AUTH_API_KEY` is created from the `auth_api_key` variable.

## Outputs

After deployment, you'll get:

| Output                             | Description                            |
| ---------------------------------- | -------------------------------------- |
| `application_url`                  | Primary application URL                |
| `alb_dns_name`                     | Load balancer DNS name                 |
| `database_endpoint`                | PostgreSQL endpoint (internal)         |
| `redis_endpoint`                   | Redis endpoint (internal)              |
| `runlayer_tool_guard_enabled`      | Runlayer ToolGuard deployment status   |
| `runlayer_tool_guard_endpoint_url` | Runlayer ToolGuard URL (if enabled)    |

## Deployment Types

### Development

- Minimal resources
- Local Terraform state
- Cost-optimized

### Production

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

- **Logs:** CloudWatch `anysource-backend-logs-[env]`, `anysource-frontend-logs-[env]` (main containers)
- **Migration Logs:** CloudWatch `anysource-prestart-logs-[env]` (database setup)
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

## Monitoring & Observability

Runlayer ECS deployments include comprehensive monitoring:

### CloudWatch Integration

- **Logs:** All containers stream logs to `anysource-[service]-logs-[env]` and `anysource-prestart-logs-[env]`
- **Metrics:** CPU, memory, task count, and health check metrics
- **Alarms:** Service health and resource saturation alerts
- **Dashboards:** Built-in ECS service dashboards

### Log Groups

- `anysource-backend-logs-[environment]` - Backend application logs
- `anysource-frontend-logs-[environment]` - Frontend application logs
- `anysource-prestart-logs-[environment]` - Database migration and setup logs

### Troubleshooting

Use CloudWatch logs and ECS service events to diagnose issues. Common problems like task failures and migration errors are logged for rapid analysis.

## Architecture Features

- **High Availability:** Multi-AZ deployment with auto-scaling
- **Security:** Private database subnets, security groups, SSL/TLS
- **Scalability:** Auto-scaling based on CPU/memory metrics
- **Reliability:** Automated backups, health checks, load balancing
- **Monitoring:** CloudWatch integration, ECS service events, alarms, dashboards
- **Secrets Management:** AWS Secrets Manager integration
