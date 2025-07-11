# ========================================
# TERRAFORM BACKEND CONFIGURATION
# ========================================
# Configuration for storing Terraform state in AWS S3
# Copy this file to `backend.tfvars` and customize for your deployment

# S3 Backend Configuration (required)
bucket = "your-terraform-state-bucket"
key    = "anysource/terraform.tfstate"
region = "us-east-1"

# Optional: AWS Profile (if not using default credentials)
# profile = "your-aws-profile"

# Optional: State Locking with DynamoDB (recommended for teams)
# dynamodb_table = "terraform-state-lock"

# Optional: Server-side Encryption (recommended for security)
# encrypt = true
# kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

# ========================================
# USAGE EXAMPLES
# ========================================
# 
# Production with S3 backend:
#   cp examples/backend.tfvars backend.tfvars
#   terraform init -backend-config=backend.tfvars
# 
# Development with local state:
#   terraform init -backend=false
# 
# Reconfigure backend:
#   terraform init -backend-config=backend.tfvars -reconfigure
# 
# ========================================
# SETUP INSTRUCTIONS
# ========================================
# 1. Create S3 bucket for state storage:
#    aws s3 mb s3://your-terraform-state-bucket
# 
# 2. Enable versioning (recommended):
#    aws s3api put-bucket-versioning \
#      --bucket your-terraform-state-bucket \
#      --versioning-configuration Status=Enabled
# 
# 3. Create DynamoDB table for locking (optional):
#    aws dynamodb create-table \
#      --table-name terraform-state-lock \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST 
