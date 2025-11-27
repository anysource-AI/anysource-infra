# ALB Security Group with configurable access
module "sg_alb" {
  source      = "./modules/security-group"
  name        = "${var.project}-${var.alb_access_type}-alb"
  description = "${var.project} ${var.alb_access_type} ALB security group"
  vpc_id      = local.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.alb_access_type == "private" ? [var.vpc_cidr] : var.alb_allowed_cidrs
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.alb_access_type == "private" ? [var.vpc_cidr] : var.alb_allowed_cidrs
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Local variables for VPC peering security group configuration
locals {
  peered_vpc_cidrs       = [for peer in var.vpc_peering_connections : peer.peer_vpc_cidr]
  internal_allowed_cidrs = concat([var.vpc_cidr], local.peered_vpc_cidrs)
}

# Internal ALB Security Group (for dual ALB setup)
module "sg_alb_internal" {
  count       = var.enable_dual_alb ? 1 : 0
  source      = "./modules/security-group"
  name        = "${var.project}-internal-alb"
  description = "${var.project} internal ALB security group (private network access only)"
  vpc_id      = local.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = local.internal_allowed_cidrs
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = local.internal_allowed_cidrs
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
