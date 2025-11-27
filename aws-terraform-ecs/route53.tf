locals {
  sanitized_hosted_zone = trimspace(var.hosted_zone_name)
  route53_zone_name     = local.sanitized_hosted_zone != "" ? local.sanitized_hosted_zone : var.domain_name
}

# Public hosted zone lookup (for ACM validation and public DNS)
data "aws_route53_zone" "application" {
  count        = var.enable_acm_dns_validation ? 1 : 0
  name         = local.route53_zone_name
  private_zone = false
}

# Public ALB DNS record
resource "aws_route53_record" "alb_alias" {
  count           = var.enable_acm_dns_validation ? 1 : 0
  zone_id         = var.enable_acm_dns_validation ? data.aws_route53_zone.application[0].zone_id : null
  name            = var.domain_name
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Private hosted zone for internal ALB (split-horizon DNS)
resource "aws_route53_zone" "private" {
  count         = var.enable_dual_alb && var.private_hosted_zone_id == "" ? 1 : 0
  name          = var.domain_name
  comment       = "Runlayer internal zone for split-horizon DNS"
  force_destroy = false

  vpc {
    vpc_id = var.private_hosted_zone_vpc_id != "" ? var.private_hosted_zone_vpc_id : local.vpc_id
  }

  tags = {
    Name        = "${var.project}-${var.environment}-private-zone"
    Project     = var.project
    Environment = var.environment
  }
}

# Associate service VPC with existing private hosted zone
# (New zones automatically associate the service VPC via the vpc block)
resource "aws_route53_zone_association" "service_vpc" {
  count   = var.enable_dual_alb && var.private_hosted_zone_id != "" ? 1 : 0
  zone_id = var.private_hosted_zone_id
  vpc_id  = var.private_hosted_zone_vpc_id != "" ? var.private_hosted_zone_vpc_id : local.vpc_id
}

# Associate private zone with additional VPCs (same-account only)
# Works for both new and existing private hosted zones
resource "aws_route53_zone_association" "additional_vpcs" {
  count   = var.enable_dual_alb ? length(var.private_hosted_zone_additional_vpc_ids) : 0
  zone_id = var.private_hosted_zone_id != "" ? var.private_hosted_zone_id : aws_route53_zone.private[0].zone_id
  vpc_id  = var.private_hosted_zone_additional_vpc_ids[count.index]
}

# Internal ALB DNS record (private hosted zone)
resource "aws_route53_record" "internal_alb_alias" {
  count           = var.enable_dual_alb ? 1 : 0
  zone_id         = var.private_hosted_zone_id != "" ? var.private_hosted_zone_id : aws_route53_zone.private[0].zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = module.alb_internal[0].alb_dns_name
    zone_id                = module.alb_internal[0].alb_zone_id
    evaluate_target_health = true
  }
}
