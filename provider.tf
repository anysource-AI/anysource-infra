
provider "aws" {
  region = var.region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend (for production/shared environments)
  backend "s3" {}

  # Example with specific S3 backend configuration (commented out)
  #   backend "s3" {
  #     bucket  = var.terraform_state_bucket
  #     key     = var.terraform_state_key
  #     region  = var.region
  #     profile = var.profile
  # }
}

# Uncomment below for local state (for development/testing)
# backend "local" {
#   path = "terraform.tfstate"
# }
