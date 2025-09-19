module "iam" {
  source      = "./modules/iam"
  project     = var.project
  environment = var.environment
  account_id  = var.account
  region      = var.region
}

module "roles_micro_services" {
  source      = "./modules/roles_iam"
  project     = var.project
  environment = var.environment
  account     = var.account
  region      = var.region
}
