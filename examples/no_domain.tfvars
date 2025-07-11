# ========================================
# NO DOMAIN DEPLOYMENT CONFIGURATION
# ========================================
# Simple HTTP deployment accessible via ALB DNS name
# Perfect for development, testing, or simple deployments

# Required Configuration (minimum needed)
environment     = "development"
region          = "us-east-1"
first_superuser = "admin@yourcompany.com"

# ECR Configuration (required)
ecr_repositories = {
  backend  = "<the ECR URI for your backend image here>"
  frontend = "<the ECR URI for your frontend image here>"
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
