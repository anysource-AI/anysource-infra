terraform {
  ### S3 Backend Configuration ###
  # Comment this when using local state
  backend "s3" {}

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
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "anysource"
      Owner       = "platform-team"
    }
  }

  # Retry configuration for better reliability
  retry_mode  = "adaptive"
  max_retries = 3
}

# The Kubernetes provider is included here because the EKS module creates the cluster,
# and we want to be able to add Kubernetes resources in the same configuration.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
