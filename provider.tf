
provider "aws" {
  region  = var.region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
#   backend "s3" {
#     bucket  = var.terraform_state_bucket
#     key     = var.terraform_state_key
#     region  = var.region
#     profile = var.profile
# }
}
