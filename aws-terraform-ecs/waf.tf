module "waf" {
  source        = "./modules/waf"
  name          = "alb"
  environment   = var.environment
  project       = var.project
  metric_name   = "alb-${var.project}-${var.environment}"
  resources_arn = [module.alb.alb_arn]
}
