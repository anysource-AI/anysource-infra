########################################################################################################################
# Data Sources
########################################################################################################################

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Get VPC information (only when not creating VPC)
data "aws_vpc" "selected" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

# Get private subnets if not provided (only when not creating VPC)
data "aws_subnets" "private" {
  count = var.create_vpc ? 0 : (length(var.private_subnet_ids) == 0 ? 1 : 0)

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*", "*Private*"]
  }
}

# Get public subnets if not provided (only when not creating VPC)
data "aws_subnets" "public" {
  count = var.create_vpc ? 0 : (length(var.public_subnet_ids) == 0 ? 1 : 0)

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*public*", "*Public*"]
  }
}

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Get existing EKS cluster information (only when not creating EKS)
data "aws_eks_cluster" "existing" {
  count = var.create_eks ? 0 : 1
  name  = var.existing_cluster_name
}

# Get EKS cluster auth token
data "aws_eks_cluster_auth" "cluster" {
  name = var.create_eks ? module.eks[0].cluster_name : var.existing_cluster_name
}
