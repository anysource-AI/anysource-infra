########################################################################################################################
# VPC Module (Optional)
########################################################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  count = var.create_vpc ? 1 : 0

  name = "${var.project}-${var.environment}"
  cidr = var.vpc_cidr

  azs             = length(var.region_az) > 0 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "production" # 1 NAT for non-prod
  one_nat_gateway_per_az = var.environment == "production" # 3 NATs for prod

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}"
  })

  # Public subnet tags with custom Name per AZ
  public_subnet_tags = merge(local.common_tags, {
    Type                                          = "public"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })

  public_subnet_tags_per_az = {
    for idx, az in(length(var.region_az) > 0 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 3)) :
    az => {
      Name = "${var.project}-${var.environment}-public-${az}"
    }
  }

  # Private subnet tags with custom Name per AZ
  private_subnet_tags = merge(local.common_tags, {
    Type                                          = "private"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })

  private_subnet_tags_per_az = {
    for idx, az in(length(var.region_az) > 0 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 3)) :
    az => {
      Name = "${var.project}-${var.environment}-private-${az}"
    }
  }
}
