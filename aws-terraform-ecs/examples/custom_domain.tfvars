# ========================================
# CUSTOM DOMAIN DEPLOYMENT CONFIGURATION
# ========================================
# Standard HTTPS deployment with automatic SSL certificate
# Perfect for production with your own domain

# Required Configuration
environment       = "production"
region            = "us-east-1"
domain_name       = "mcp.yourcompany.com"      # Replace with your domain
auth_domain       = "your-tenant.us.auth0.com" # will be provided by Anysource support
auth_client_id    = "your-auth0-client-id"     # will be provided by Anysource support
database_username = "postgres"

# ECR Configuration (required)
ecr_repositories = {
  backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
}

# Secrets Configuration
suffix_secret_hash = "ANY2025"

# Required: HuggingFace token for prompt protection models
hf_token = "hf_your_token_here" # Replace with your actual token

# ACM Certificate ARN for your domain (required for HTTPS)
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-certificate-id" # Replace with your ACM certificate ARN

# ========================================
# OPTIONAL CUSTOMIZATION
# ========================================

# Network Security (optional)
# alb_allowed_cidrs = [
#   "203.0.113.0/24",    # Your office IP range
#   "198.51.100.0/24"    # Your VPN IP range  
# ]

# Database Configuration (optional)
# database_config = {
#   min_capacity     = 8      # Increase for production load
#   max_capacity     = 32     # Maximum scaling capacity
#   backup_retention = 30     # Days to keep backups
# }

# Service Scaling (optional)
# services_configurations = {
#   "backend" = {
#     desired_count = 3    # Number of backend instances
#     max_capacity  = 10   # Maximum scaling capacity
#   }
#   "frontend" = {
#     desired_count = 2    # Number of frontend instances
#     max_capacity  = 6    # Maximum scaling capacity
#   }
# }

# ========================================
# DEPLOYMENT FEATURES
# ========================================
# ✓ HTTPS with automatic SSL certificate (ACM)
# ✓ Automatic DNS validation
# ✓ Production-ready defaults
# ✓ Professional domain access
# ✓ Secure CORS configuration
# ✓ Auto-scaling enabled

# ========================================
# QUICK DEPLOYMENT
# ========================================
# 1. Copy this file: cp examples/custom_domain.tfvars terraform.tfvars
# 2. Update domain_name to your actual domain
# 3. Update your email and HF token
# 4. Ensure domain DNS points to AWS (or manage externally)
# 5. Deploy: terraform apply
# 6. Access via https://your-domain.com 
