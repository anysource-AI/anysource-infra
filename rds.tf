# Simplified RDS configuration with smart defaults
locals {
  # Use new database_config structure
  db_config = {
    (var.database_name) = {
      engine_version = var.database_config.engine_version
      min_capacity   = var.database_config.min_capacity
      max_capacity   = var.database_config.max_capacity
      count_replicas = 2 # Default for production
    }
  }

  # Determine subnet selection based on database_config.subnet_type
  db_subnet_ids = var.database_config.subnet_type == "public" ? module.vpc.public_subnets : module.vpc.private_subnets
}

module "rds" {
  for_each            = local.db_config
  source              = "./modules/rds"
  environment         = var.environment
  project             = var.project
  name                = each.key
  engine_version      = each.value.engine_version
  min_capacity        = each.value.min_capacity
  max_capacity        = each.value.max_capacity
  availability_zones  = length(var.region_az) > 0 ? [var.region_az[0]] : [data.aws_availability_zones.available.names[0]]
  subnet_ids          = local.db_subnet_ids
  publicly_accessible = var.database_config.publicly_accessible
  vpc_id              = module.vpc.vpc_id
  count_replicas      = each.value.count_replicas
  vpc_cidr            = var.vpc_cidr
  deletion_protection = var.deletion_protection
  db_username         = jsondecode(aws_secretsmanager_secret_version.app_secrets.secret_string)["PLATFORM_DB_USERNAME"]
  db_password         = jsondecode(aws_secretsmanager_secret_version.app_secrets.secret_string)["PLATFORM_DB_PASSWORD"]
}

# Auto-populate availability zones if not provided
data "aws_availability_zones" "available" {
  state = "available"
}
