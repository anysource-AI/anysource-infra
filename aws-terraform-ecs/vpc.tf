# VPC module is only created if existing_vpc_id is not provided
module "vpc" {
  count                                           = var.existing_vpc_id == null ? 1 : 0
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

# Validate VPC configuration - all three variables must be provided together or all must be null
check "vpc_configuration" {
  assert {
    condition = (
      (var.existing_vpc_id == null && var.existing_private_subnet_ids == null && var.existing_public_subnet_ids == null) ||
      (var.existing_vpc_id != null && var.existing_private_subnet_ids != null && var.existing_public_subnet_ids != null)
    )
    error_message = "VPC configuration error: If using an existing VPC, all three variables (existing_vpc_id, existing_private_subnet_ids, existing_public_subnet_ids) must be provided. If creating a new VPC, all three must be null."
  }
}
