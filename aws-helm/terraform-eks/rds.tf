########################################################################################################################
# RDS Aurora PostgreSQL
########################################################################################################################

# DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = local.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

# DB Cluster Parameter Group (for Aurora cluster-level parameters like SSL)
resource "aws_rds_cluster_parameter_group" "rds_cluster" {
  family = "aurora-postgresql16"
  name   = "${var.project}-${var.environment}-db-cluster-params"

  parameter {
    name         = "rds.force_ssl"
    value        = var.database_config.force_ssl ? "1" : "0"
    apply_method = "pending-reboot"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-db-cluster-params"
  })
}

# DB Parameter Group (for instance-level parameters)
resource "aws_db_parameter_group" "rds" {
  family = "aurora-postgresql16"
  name   = "${var.project}-${var.environment}-db-params"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-db-params"
  })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project}-${var.environment}-rds-"
  vpc_id      = local.vpc_id

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

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-rds-sg"
  })
}

module "rds" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.0"

  name           = "${var.project}-${var.environment}-db"
  engine         = "aurora-postgresql"
  engine_version = var.database_config.engine_version
  engine_mode    = "provisioned"

  vpc_id               = local.vpc_id
  db_subnet_group_name = aws_db_subnet_group.rds.name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = [var.vpc_cidr]
    }
  }

  master_username             = var.database_username
  master_password             = var.database_password
  manage_master_user_password = false
  database_name               = var.database_name

  # Multi-AZ configuration
  availability_zones = local.availability_zones

  serverlessv2_scaling_configuration = {
    min_capacity = var.database_config.min_capacity
    max_capacity = var.database_config.max_capacity
  }

  instances = var.environment == "production" ? {
    1 = {
      instance_class      = "db.serverless"
      publicly_accessible = false
    }
    2 = {
      instance_class      = "db.serverless"
      publicly_accessible = false
    }
    } : {
    1 = {
      instance_class      = "db.serverless"
      publicly_accessible = false
    }
  }

  storage_encrypted   = true
  apply_immediately   = true
  deletion_protection = var.database_config.deletion_protection
  skip_final_snapshot = var.database_config.skip_final_snapshot

  db_parameter_group_name         = aws_db_parameter_group.rds.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.rds_cluster.name

  tags = local.common_tags
}

########################################################################################################################
# RDS Monitoring Alarms
########################################################################################################################

# RDS CPU Utilization Alarm
module "rds_cpu_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "~> 3.0"

  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-rds-cpu"
  alarm_description   = "RDS CPU utilization exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  period              = 300
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = module.rds.cluster_id
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

# RDS Database Connections Alarm
module "rds_connections_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "~> 3.0"

  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-rds-connections"
  alarm_description   = "RDS database connections exceed threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 50
  period              = 300
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = module.rds.cluster_id
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

# RDS Freeable Memory Alarm
module "rds_memory_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "~> 3.0"

  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-rds-memory"
  alarm_description   = "RDS freeable memory below threshold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  threshold           = 268435456 # 256MB
  period              = 300
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = module.rds.cluster_id
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}
