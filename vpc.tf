module "vpc" {
  source          = "./modules/vpc"
  name            = "${var.project}-${var.environment}"
  vpc_cidr        = var.vpc_cidr
  environment     = var.environment
  region          = var.region
  region_az       = length(var.region_az) > 0 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}
