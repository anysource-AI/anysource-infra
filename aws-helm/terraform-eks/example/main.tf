terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "runlayer/eks/production/tfstate.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
  required_version = ">= 1.7"
}

locals {
  region  = "us-east-1"
  account = "123456789012" # Replace with your AWS account ID
}

provider "aws" {
  region = local.region
}

# ========================================
# MODE 1: NEW VPC + NEW EKS CLUSTER (Default)
# ========================================

module "eks_cluster" {
  source = "git::https://github.com/anysource-AI/runlayer-infra.git//aws-helm/terraform-eks?ref=${var.release_version}"

  # Core Configuration
  region  = local.region
  account = local.account

  # SSO Admin Access (Optional - if you use AWS SSO for administration)
  # This auto-constructs access entry and base KMS permissions
  # Comment out or remove if you don't use AWS SSO
  sso_admin_role_arn = "arn:aws:iam::${local.account}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess_xxxxx"

  # EKS Configuration
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Database Configuration
  database_password = var.database_password

  # Application Secrets
  secret_key   = var.secret_key
  master_salt  = var.master_salt
  auth_api_key = var.auth_api_key

  # EKS Namespace
  eks_namespace = var.eks_namespace

  # Access entries for API-based access control
  # Note: SSO admin is auto-constructed from sso_admin_role_arn above
  # Add additional access entries here as needed (e.g., CI/CD roles, developer access)
  # Example:
  # access_entries = {
  #   cicd_role = {
  #     principal_arn = "arn:aws:iam::${local.account}:role/your-cicd-role"
  #     policy_associations = {
  #       cluster_admin = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #         }
  #       }
  #     }
  #     kubernetes_groups = []
  #     type              = "STANDARD"
  #   }
  # }
}

# ========================================
# MODE 2: EXISTING VPC + NEW EKS CLUSTER
# ========================================
# Uncomment this module to create a new EKS cluster in an existing VPC
# Comment out MODE 1 above when using this mode

# module "eks_cluster" {
#   source = "git::https://github.com/anysource-AI/runlayer-infra.git//aws-helm/terraform-eks?ref=${var.release_version}"
#
#   # Core Configuration
#   region      = local.region
#   account     = local.account
#
#   # Use Existing VPC
#   create_vpc         = false
#   vpc_id             = var.vpc_id
#   private_subnet_ids = var.private_subnet_ids
#   public_subnet_ids  = var.public_subnet_ids
#
#   # SSO Admin Access (Optional - if you use AWS SSO for administration)
#   # This auto-constructs access entry and base KMS permissions
#   # Comment out or remove if you don't use AWS SSO
#   sso_admin_role_arn = "arn:aws:iam::${local.account}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess_xxxxx"
#
#   # EKS Configuration
#   cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
#
#   # Database Configuration
#   database_password = var.database_password
#
#   # Application Secrets
#   secret_key   = var.secret_key
#   master_salt  = var.master_salt
#   auth_api_key = var.auth_api_key
#
#   # EKS Namespace
#   eks_namespace = var.eks_namespace
#
#   # Access entries for API-based access control
#   # Note: SSO admin is auto-constructed from sso_admin_role_arn above
#   # Add additional access entries here as needed (e.g., CI/CD roles, developer access)
#   # Example:
#   # access_entries = {
#   #   cicd_role = {
#   #     principal_arn = "arn:aws:iam::${local.account}:role/your-cicd-role"
#   #     policy_associations = {
#   #       cluster_admin = {
#   #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#   #         access_scope = {
#   #           type = "cluster"
#   #         }
#   #       }
#   #     }
#   #     kubernetes_groups = []
#   #     type              = "STANDARD"
#   #   }
#   # }
# }

# ========================================
# MODE 3: EXISTING VPC + EXISTING EKS CLUSTER
# ========================================
# Uncomment this module to add application infrastructure to an existing EKS cluster
# Comment out MODE 1 above when using this mode

# module "eks_cluster" {
#   source = "git::https://github.com/anysource-AI/runlayer-infra.git//aws-helm/terraform-eks?ref=${var.release_version}"
#
#   # Core Configuration
#   region      = local.region
#   account     = local.account
#
#   # Use Existing VPC (required when using existing EKS)
#   create_vpc         = false
#   vpc_id             = var.vpc_id
#   private_subnet_ids = var.private_subnet_ids
#   public_subnet_ids  = var.public_subnet_ids
#
#   # Use Existing EKS Cluster
#   create_eks                 = false
#   existing_cluster_name      = var.existing_cluster_name
#   existing_oidc_provider_arn = var.existing_oidc_provider_arn
#
#   # Database Configuration
#   database_password = var.database_password
#
#   # Application Secrets
#   secret_key   = var.secret_key
#   master_salt  = var.master_salt
#   auth_api_key = var.auth_api_key
#
#   # EKS Namespace
#   eks_namespace = var.eks_namespace
# }
