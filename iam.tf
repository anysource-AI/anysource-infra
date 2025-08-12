module "iam" {
  source      = "./modules/iam"
  project     = var.project
  environment = var.environment
  account_id  = var.account
  region      = var.region
}

module "roles_micro_services" {
  source             = "./modules/roles_iam"
  project            = var.project
  role_names         = keys(var.services_configurations)
  environment        = var.environment
  account            = var.account
  suffix_secret_hash = var.suffix_secret_hash
  region             = var.region
}
