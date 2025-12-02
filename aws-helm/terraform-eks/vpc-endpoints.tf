########################################################################################################################
# VPC Endpoints Module for Cost Optimization
########################################################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  # Only create endpoints when VPC is created and endpoints are enabled
  create = var.create_vpc && var.enable_vpc_endpoints

  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id

  # Create a security group for interface endpoints
  create_security_group      = true
  security_group_name_prefix = "${var.project}-${var.environment}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = var.create_vpc ? [module.vpc[0].vpc_cidr_block] : []
    }
  }

  endpoints = {
    # S3 Gateway Endpoint - FREE
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = var.create_vpc ? flatten([module.vpc[0].private_route_table_ids, module.vpc[0].public_route_table_ids]) : []
      tags            = { Name = "${var.project}-${var.environment}-s3-endpoint" }
    }

    # ECR API Endpoint - Essential for container image metadata during deployments
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = var.create_vpc ? module.vpc[0].private_subnets : []
      tags                = { Name = "${var.project}-${var.environment}-ecr-api-endpoint" }
    }

    # ECR Docker Endpoint - Essential for pulling Docker image layers
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = var.create_vpc ? module.vpc[0].private_subnets : []
      tags                = { Name = "${var.project}-${var.environment}-ecr-dkr-endpoint" }
    }

    # CloudWatch Logs Endpoint - High-volume continuous log streaming from pods
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = var.create_vpc ? module.vpc[0].private_subnets : []
      tags                = { Name = "${var.project}-${var.environment}-logs-endpoint" }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-vpc-endpoints"
  })
}
