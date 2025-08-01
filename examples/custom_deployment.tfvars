# ========================================
# CUSTOM ENTERPRISE DEPLOYMENT CONFIGURATION
# ========================================
# Full customization options for enterprise deployments
# Copy and modify sections as needed for your requirements

# ========================================
# REQUIRED CONFIGURATION
# ========================================
environment     = "production"
region          = "us-east-1"
first_superuser = "admin@yourcompany.com"
domain_name     = "mcp.yourcompany.com"

# ECR Configuration (required)
ecr_repositories = {
  backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
  # For private ECR: "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:tag"
}

# Secrets Configuration
suffix_secret_hash = "ANY2025"
hf_token           = "hf_your_token_here"

# ========================================
# NETWORK CONFIGURATION
# ========================================
cidr            = "10.0.0.0/16"
region_az       = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

# ========================================
# SECURITY CONFIGURATION
# ========================================
alb_access_type = "public" # or "private" for VPC-only access
alb_allowed_cidrs = [
  "203.0.113.0/24",  # Office IP range
  "198.51.100.0/24", # VPN IP range
  # "0.0.0.0/0"        # Internet access (comment out for IP restrictions)
]

# SSL Certificate Options
# Option 1: Use existing certificate
ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Option 2: Auto-create certificate (comment out ssl_certificate_arn above)
# create_route53_records = true
# hosted_zone_id = "Z1234567890ABC"

# ========================================
# DATABASE CONFIGURATION
# ========================================
database_name = "anysource_prod"
database_username = "postgres"
database_config = {
  engine_version      = "16.6"    # PostgreSQL version
  min_capacity        = 8         # Minimum Aurora capacity (ACUs)
  max_capacity        = 64        # Maximum Aurora capacity (ACUs)
  publicly_accessible = false     # Keep private (recommended)
  backup_retention    = 30        # Backup retention in days
  subnet_type         = "private" # Use private subnets
}

# ========================================
# APPLICATION SCALING & PERFORMANCE
# ========================================
services_configurations = {
  "backend" = {
    path_pattern      = ["/api/*"]
    health_check_path = "/api/v1/utils/health-check/"
    desired_count     = 4    # Production instances
    min_capacity      = 2    # Minimum for HA
    max_capacity      = 20   # Maximum scaling
    cpu               = 2048 # 2 vCPU
    memory            = 4096 # 4 GB RAM
    container_port    = 8000
    host_port         = 8000

    # Auto-scaling thresholds
    cpu_auto_scalling_target_value    = 60 # Scale at 60% CPU
    memory_auto_scalling_target_value = 70 # Scale at 70% memory

    # Environment variables
    env_vars = {
      DEBUG          = "False"
      LOG_LEVEL      = "INFO"
      WORKER_TIMEOUT = "300"
      MAX_WORKERS    = "4"
    }
  }

  "frontend" = {
    path_pattern      = ["/*"]
    health_check_path = "/"
    desired_count     = 3    # Production instances
    min_capacity      = 2    # Minimum for HA
    max_capacity      = 10   # Maximum scaling
    cpu               = 1024 # 1 vCPU
    memory            = 2048 # 2 GB RAM
    container_port    = 80
    host_port         = 80

    # Auto-scaling thresholds
    cpu_auto_scalling_target_value    = 60
    memory_auto_scalling_target_value = 70
  }
}

# ========================================
# GLOBAL CONFIGURATION
# ========================================
env_vars = {
  ENVIRONMENT = "production"
  REGION      = "us-east-1"
  COMPANY     = "YourCompany"
  LOG_LEVEL   = "INFO"
}

secret_vars = {
  JWT_SECRET_KEY = "your-jwt-secret"
  API_SECRET_KEY = "your-api-secret"
  ENCRYPTION_KEY = "your-encryption-key"
}

# ========================================
# OPTIONAL SERVICES
# ========================================
# Additional S3 buckets
buckets_conf = {
  "document-storage" = { acl = "private" }
  "user-uploads"     = { acl = "private" }
  "backups"          = { acl = "private" }
  "logs"             = { acl = "private" }
}

# ========================================
# ENTERPRISE FEATURES
# ========================================
# Advanced configuration
project = "anysource"
profile = "default"

# Multi-environment support
# env_specific_config = {
#   production = {
#     min_capacity = 8
#     max_capacity = 64
#   }
#   staging = {
#     min_capacity = 2
#     max_capacity = 16
#   }
# }

# ========================================
# DEPLOYMENT CHECKLIST
# ========================================
# □ Update domain_name to your actual domain
# □ Configure SSL certificate (existing or auto-create)
# □ Set appropriate IP restrictions in alb_allowed_cidrs
# □ Adjust scaling parameters for expected load
# □ Review database capacity settings
# □ Configure monitoring and alerting (outside Terraform)
# □ Set up backup procedures
# □ Configure log aggregation
# □ Review security groups and network ACLs
# □ Test disaster recovery procedures 
