# Request and validate an SSL certificate from AWS Certificate Manager (ACM)
resource "aws_acm_certificate" "certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags = {
    Environment = var.environment
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "customer_domain" {
  count        = var.enable_acm_dns_validation ? 1 : 0
  name         = var.hosted_zone_name != "" ? var.hosted_zone_name : var.domain_name
  private_zone = false
}

locals {
  acm_validation_records = var.enable_acm_dns_validation ? {
    for dvo in aws_acm_certificate.certificate.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  customer_zone_id = var.enable_acm_dns_validation ? data.aws_route53_zone.customer_domain[0].zone_id : null
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.acm_validation_records

  zone_id = local.customer_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.enable_acm_dns_validation ? 1 : 0
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]

  timeouts {
    create = "5m"
  }
}
