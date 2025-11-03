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
  db_subnet_ids = var.database_config.subnet_type == "public" ? local.public_subnet_ids : local.private_subnet_ids
}

module "rds" {
  for_each                = local.db_config
  source                  = "./modules/rds"
  environment             = var.environment
  project                 = var.project
  name                    = each.key
  engine_version          = each.value.engine_version
  min_capacity            = each.value.min_capacity
  max_capacity            = each.value.max_capacity
  availability_zones      = length(var.region_az) >= 2 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 2)
  subnet_ids              = local.db_subnet_ids
  publicly_accessible     = var.database_config.publicly_accessible
  vpc_id                  = local.vpc_id
  count_replicas          = each.value.count_replicas
  vpc_cidr                = var.vpc_cidr
  deletion_protection     = var.deletion_protection
  db_username             = var.database_username
  db_password_secret_name = aws_secretsmanager_secret.app_secrets.name

  # Set parameter group family based on engine version for SSL enforcement
  parameter_group_family = startswith(each.value.engine_version, "16") ? "aurora-postgresql16" : startswith(each.value.engine_version, "15") ? "aurora-postgresql15" : startswith(each.value.engine_version, "14") ? "aurora-postgresql14" : "aurora-postgresql16"

  # SSL enforcement - defaults to 0 (optional) for backward compatibility
  force_ssl = var.database_config.force_ssl

  # Snapshot configuration
  skip_final_snapshot      = var.database_config.skip_final_snapshot
  delete_automated_backups = var.database_config.delete_automated_backups

  # Backup retention - environment-specific defaults
  backup_retention_period = var.environment == "staging" ? 7 : var.environment == "development" ? 1 : 14
}

# Auto-populate availability zones if not provided
data "aws_availability_zones" "available" {
  state = "available"
}
