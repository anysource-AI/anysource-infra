module "vpc" {
  source                                          = "./modules/vpc"
  vpc_cidr                                        = var.vpc_cidr
  project                                         = var.project
  environment                                     = var.environment
  region                                          = var.region
  region_az                                       = length(var.region_az) > 0 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets                                 = var.private_subnets
  public_subnets                                  = var.public_subnets
  flow_log_cloudwatch_log_group_name              = "/aws/vpc-flow-log/${var.project}-${var.environment}"
  flow_log_cloudwatch_log_group_retention_in_days = 365
  flow_log_iam_role_name                          = "vpc-flow-logs-role-${var.project}-${var.environment}"
  flow_log_traffic_type                           = "ALL"
}
