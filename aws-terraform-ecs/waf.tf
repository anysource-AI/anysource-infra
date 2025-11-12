module "waf" {
  source                 = "./modules/waf"
  name                   = "alb"
  environment            = var.environment
  project                = var.project
  metric_name            = "alb-${var.project}-${var.environment}"
  resources_arn          = [module.alb.alb_arn]
  enable_ip_allowlisting = var.waf_enable_ip_allowlisting
  allowlist_ipv4_cidrs   = var.waf_allowlist_ipv4_cidrs
}
