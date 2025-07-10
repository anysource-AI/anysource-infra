
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

  # Backend configuration is handled via external files to avoid CI prompts:
  # 
  # For S3 remote state (production):
  #   terraform init -backend-config=backend.tfvars
  # 
  # For local state (development):
  #   terraform init -backend=false
  # 
  # See backend.tfvars.example for S3 configuration template
}
