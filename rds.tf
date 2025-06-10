# Simplified RDS configuration with smart defaults
locals {
  # Merge legacy rds_conf with new database_config for backward compatibility
  # Prefer new database_config if both are provided
  merged_db_config = length(var.rds_conf) > 0 ? var.rds_conf : {
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
  for_each            = local.merged_db_config
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
  secret_arn          = aws_secretsmanager_secret.app_secrets.arn
}

# Auto-populate availability zones if not provided
data "aws_availability_zones" "available" {
  state = "available"
}
