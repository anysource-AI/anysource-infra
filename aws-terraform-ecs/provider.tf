
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
