# Backend configuration is handled via external files to avoid CI prompts:
# 
# For S3 remote state (production):
#   terraform init -backend-config=backend.tfvars
# 
# For local state (development):
#   terraform init -backend=false

### Local Backend Configuration (for development/testing)
# Uncomment below to use local state instead of S3
# NOTE: Only one backend block can be active; comment the "s3" block above first.

# backend "local" {
#   path = "terraform.tfstate"
# }

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = var.project
      Owner       = "platform-team"
    }
  }

  # Retry configuration for better reliability
  retry_mode  = "adaptive"
  max_retries = 3
}

# The Kubernetes provider is included here because the EKS module creates the cluster,
# and we want to be able to add Kubernetes resources in the same configuration.
# When create_eks = false, these providers connect to an existing cluster.
provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
