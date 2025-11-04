terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "runlayer/production/tfstate.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.15.0"
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

module "ecs_cluster" {
  source = "git::https://github.com/anysource-AI/anysource-infra.git//aws-terraform-ecs?ref=${var.release_version}"

  # Core Configuration
  region  = local.region
  account = local.account

  # Network Configuration
  domain_name = "anysource.yourcompany.com" # Replace with your domain

  # Use Existing VPC (optional - uncomment to use existing VPC)
  # existing_vpc_id             = var.vpc_id
  # existing_private_subnet_ids = var.private_subnet_ids
  # existing_public_subnet_ids  = var.public_subnet_ids

  # Auth Configuration (provided by Anysource support)
  auth_client_id = var.auth_client_id
  auth_api_key   = var.auth_api_key

  # Container Images
  ecr_repositories = var.ecr_repositories

  # SSL Certificate (optional - will create ACM certificate if not provided)
  # ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-certificate-id"

  # Monitoring (optional)
  # enable_monitoring = true
  # sentry_dsn        = var.sentry_dsn
}
