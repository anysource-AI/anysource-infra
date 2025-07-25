# ALB with configurable certificate and access type
module "private_alb" {
  source             = "./modules/alb"
  name               = "${var.project}-${var.alb_access_type}-alb-${var.environment}"
  load_balancer_type = "application"
  environment        = var.environment
  subnets            = module.vpc.public_subnets
  vpc_id             = module.vpc.vpc_id
  target_groups      = var.services_configurations
  internal           = var.alb_access_type == "private"
  security_groups    = [module.sg_private_alb.security_group_id]
  certificate_arn    = local.enable_https ? (var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : module.certificate_alb[0].certificate_arn) : ""
  enable_https       = local.enable_https
  depends_on         = [module.vpc, module.sg_private_alb]
}

# Certificate creation (only if HTTPS is enabled, domain is provided, and not using existing certificate)
module "certificate_alb" {
  count       = local.enable_https && var.domain_name != "" && var.ssl_certificate_arn == "" ? 1 : 0
  source      = "./modules/acm"
  domain_name = var.domain_name
  environment = var.environment
}
