locals {
  db_engine   = "aurora"
  environment = var.environment == "production" ? "prod" : var.environment
}

data "aws_secretsmanager_secret" "db_password" {
  name = var.db_password_secret_name
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

# DB Cluster Parameter Group to enforce SSL connections
resource "aws_rds_cluster_parameter_group" "rds_cluster_pg" {
  name        = "${local.db_engine}-${var.project}-${local.environment}-cluster-pg"
  family      = var.parameter_group_family
  description = "RDS cluster parameter group for ${var.project} ${local.environment} with SSL enforcement"

  parameter {
    name         = "rds.force_ssl"
    value        = var.force_ssl ? "1" : "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking longer than 1 second
  }

  tags = {
    Name = "${local.db_engine}-${var.project}-${local.environment}-cluster-pg"
  }
}

resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier = "${local.db_engine}-${var.project}-${local.environment}-cluster"
  engine             = "${local.db_engine}-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  availability_zones = var.availability_zones
  database_name      = var.name
  master_username    = var.db_username
  master_password    = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["PLATFORM_DB_PASSWORD"]
  storage_encrypted  = true

  # Use the parameter group with SSL enforcement
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.rds_cluster_pg.name

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  skip_final_snapshot      = var.skip_final_snapshot
  deletion_protection      = var.deletion_protection
  delete_automated_backups = false
  backup_retention_period  = 10
  vpc_security_group_ids   = [aws_security_group.rds_security_group.id]
  db_subnet_group_name     = aws_db_subnet_group.subnet_group.name
  enable_http_endpoint     = local.environment == "prod" ? false : true


  # Performance Insights configuration
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.performance_insights_kms_key_id
  performance_insights_retention_period = 7

  # CloudWatch log exports
  enabled_cloudwatch_logs_exports = ["postgresql"]

  lifecycle {
    ignore_changes = [availability_zones, master_password]
  }
}


resource "aws_db_subnet_group" "subnet_group" {
  name       = "${local.db_engine}-${var.project}-${local.environment}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${local.db_engine}-${var.project}-${local.environment}-subnet-group"
  }
}

resource "aws_rds_cluster_instance" "rds_cluster_instance" {
  identifier          = "${var.project}-${local.environment}-${count.index + 1}"
  count               = var.count_replicas
  cluster_identifier  = aws_rds_cluster.rds_cluster.cluster_identifier
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.rds_cluster.engine
  engine_version      = aws_rds_cluster.rds_cluster.engine_version
  publicly_accessible = var.publicly_accessible
  availability_zone   = var.availability_zones[0]
}

resource "aws_security_group" "rds_security_group" {
  name        = "${local.db_engine}-${var.project}-${local.environment}-sg"
  description = "Security group for RDS cluster"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.db_engine}-${var.project}-${local.environment}-sg"
  }
}
