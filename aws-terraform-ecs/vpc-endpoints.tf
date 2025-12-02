########################################################################################################################
# VPC Endpoints Module for Cost Optimization
########################################################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  # Only create endpoints when creating a new VPC and endpoints are enabled
  create = var.enable_vpc_endpoints && var.existing_vpc_id == null

  vpc_id = local.vpc_id

  # Create a security group for interface endpoints
  create_security_group      = true
  security_group_name_prefix = "${var.project}-${var.environment}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  endpoints = {
    # S3 Gateway Endpoint - FREE
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = var.existing_vpc_id == null ? module.vpc[0].private_route_table_ids : []
      tags            = { Name = "${var.project}-${var.environment}-s3-endpoint" }
    }

    # ECR API Endpoint - Essential for container image metadata during deployments
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = local.private_subnet_ids
      tags                = { Name = "${var.project}-${var.environment}-ecr-api-endpoint" }
    }

    # ECR Docker Endpoint - Essential for pulling Docker image layers
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = local.private_subnet_ids
      tags                = { Name = "${var.project}-${var.environment}-ecr-dkr-endpoint" }
    }

    # CloudWatch Logs Endpoint - High-volume continuous log streaming from containers
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = local.private_subnet_ids
      tags                = { Name = "${var.project}-${var.environment}-logs-endpoint" }
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-vpc-endpoints"
    Environment = var.environment
    Project     = var.project
  }
}

########################################################################################################################
# Outputs
########################################################################################################################

output "vpc_endpoints" {
  description = "Map of VPC endpoint IDs"
  value       = module.vpc_endpoints.endpoints
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = module.vpc_endpoints.security_group_id
}
