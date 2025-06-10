locals {
  db_engine   = "aurora"
  environment = var.environment == "eu" ? "eu" : (var.environment == "production" ? "prod" : "stg")
}
resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier = "${local.db_engine}-${var.project}-${local.environment}-cluster"
  engine             = "${local.db_engine}-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  availability_zones = var.availability_zones
  database_name      = "postgres"
  master_username    = jsondecode(data.aws_secretsmanager_secret_version.secret_credentials.secret_string)["PLATFORM_DB_USERNAME"]
  master_password    = jsondecode(data.aws_secretsmanager_secret_version.secret_credentials.secret_string)["PLATFORM_DB_PASSWORD"]
  storage_encrypted  = true
  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
  skip_final_snapshot      = true
  deletion_protection      = true
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
    ignore_changes = [availability_zones]
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

data "aws_secretsmanager_secret_version" "secret_credentials" {
  secret_id = var.secret_arn
}

resource "aws_security_group" "rds_security_group" {
  name        = "${local.db_engine}-${var.project}-${local.environment}-sg"
  description = "Security group for RDS cluster"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
