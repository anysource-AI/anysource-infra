# ALB with configurable certificate and access type
module "alb" {
  source             = "./modules/alb"
  name               = "${var.project}-${var.alb_access_type}-${var.environment}"
  load_balancer_type = "application"
  project            = var.project
  environment        = var.environment
  subnets            = var.alb_access_type == "private" ? local.private_subnet_ids : local.public_subnet_ids
  vpc_id             = local.vpc_id
  target_groups      = var.services_configurations
  internal           = var.alb_access_type == "private"
  security_groups    = [module.sg_alb.security_group_id]
  certificate_arn    = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : module.certificate_alb[0].certificate_arn
  depends_on         = [module.sg_alb]
}

# Internal ALB (for dual ALB setup with split-horizon DNS)
module "alb_internal" {
  count              = var.enable_dual_alb ? 1 : 0
  source             = "./modules/alb"
  name               = "${var.project}-internal-${var.environment}"
  load_balancer_type = "application"
  project            = var.project
  environment        = var.environment
  subnets            = local.private_subnet_ids
  vpc_id             = local.vpc_id
  target_groups      = var.services_configurations
  internal           = true
  security_groups    = [module.sg_alb_internal[0].security_group_id]
  certificate_arn    = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : module.certificate_alb[0].certificate_arn
  depends_on         = [module.sg_alb_internal]
}

# Certificate creation (only if not using existing certificate)
module "certificate_alb" {
  count                     = var.ssl_certificate_arn == "" ? 1 : 0
  source                    = "./modules/acm"
  domain_name               = var.domain_name
  hosted_zone_name          = var.hosted_zone_name
  environment               = var.environment
  enable_acm_dns_validation = var.enable_acm_dns_validation
}
