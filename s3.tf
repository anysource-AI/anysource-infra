module "s3" {
  for_each = var.buckets_conf
  source         = "./modules/s3"
  environment    = var.environment
  project    = var.project
  name           = each.key
  acl           = each.value.acl
}

module "s3_new" {
  for_each = var.buckets_conf_new
  source         = "./modules/s3_new"
  environment    = var.environment
  project    = var.project
  name           = each.key
  acl           = each.value.acl
}
