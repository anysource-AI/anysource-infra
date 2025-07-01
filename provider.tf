
provider "aws" {
  region  = var.region
  profile = var.profile
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "anysource-infra-tfstate-j8cv7ypcdboj"
    key     = "anysource-production-infra/terraform.tfstate"
    region  = "us-east-1"
    profile = var.profile
  }
}
