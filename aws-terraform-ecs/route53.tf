locals {
  sanitized_hosted_zone = trimspace(var.hosted_zone_name)
  route53_zone_name     = local.sanitized_hosted_zone != "" ? local.sanitized_hosted_zone : var.domain_name
}

data "aws_route53_zone" "application" {
  count        = var.enable_acm_dns_validation ? 1 : 0
  name         = local.route53_zone_name
  private_zone = false
}

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
