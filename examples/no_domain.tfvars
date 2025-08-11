# ========================================
# NO DOMAIN DEPLOYMENT CONFIGURATION
# ========================================
# Simple HTTP deployment accessible via ALB DNS name
# Perfect for development, testing, or simple deployments

# Required Configuration (minimum needed)
environment       = "development"
region            = "us-east-1"
auth0_domain      = "your-tenant.us.auth0.com" # will be provided by Anysource support
auth0_client_id   = "your-auth0-client-id"     # will be provided by Anysource support
database_username = "postgres"

# ECR Configuration (required)
ecr_repositories = {
  backend  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  frontend = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
}

# Secrets Configuration
suffix_secret_hash = "ANY2025"

# Required: HuggingFace token for MCP protection models
hf_token = "hf_your_token_here" # Replace with your actual token

# ========================================
# DEPLOYMENT FEATURES
# ========================================
# ✓ HTTP-only access on port 80
# ✓ No SSL certificates needed
# ✓ No domain or DNS configuration required
# ✓ Application accessible via ALB DNS name (see output: application_url)
# ✓ Perfect for development and testing environments
# ✓ Minimal setup with smart production-ready defaults

# ========================================
# QUICK DEPLOYMENT
# ========================================
# 1. Copy this file: cp examples/no_domain.tfvars terraform.tfvars
# 2. Update your email and HF token above
# 3. Deploy: terraform apply
# 4. Access via the application_url output 
