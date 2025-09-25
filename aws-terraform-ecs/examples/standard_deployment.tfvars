# ========================================
# STANDARD DEPLOYMENT CONFIGURATION
# ========================================
# Standard HTTPS deployment with existing SSL certificate
# Uses our recommended defaults. Perfect for production use.

# Required Configuration
region      = "us-east-1"
domain_name = "mcp.yourcompany.com" # Replace with your domain
# ACM Certificate ARN for your domain (required for HTTPS)
ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-certificate-id"
# Will be provided by Anysource support:
auth_client_id = "auth-provider-client-id"
# ECR Configuration (required)
ecr_repositories = {
  backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
}

# Secrets
auth_api_key = "auth-provider-api-key" # will be provided by Anysource support

# ========================================
# OPTIONAL CUSTOMIZATION
# ========================================

# database_username = "postgres"

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
# ✓ HTTPS using existing ACM certificate
# ✓ Automatic DNS validation
# ✓ Production-ready defaults
# ✓ Professional domain access
# ✓ Secure CORS configuration
# ✓ Auto-scaling enabled

# ========================================
# QUICK DEPLOYMENT
# ========================================
# 1. Copy this file: cp examples/standard_deployment.tfvars terraform.tfvars
# 2. Set required values
# 3. Deploy: terraform apply
# 4. Access via https://your-domain.com
