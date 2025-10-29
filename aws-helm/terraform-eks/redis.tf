########################################################################################################################
# ElastiCache Redis
########################################################################################################################

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-${var.environment}-redis-subnet-group"
  subnet_ids = local.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-redis-subnet-group"
  })
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  name_prefix = "${var.project}-${var.environment}-redis-"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
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
    Name = "${var.project}-${var.environment}-redis-sg"
  })
}

# ElastiCache Redis Replication Group
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "Redis cluster for ${var.project} ${var.environment}"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  # Multi-AZ configuration
  num_cache_clusters         = var.environment == "production" ? 2 : 1
  automatic_failover_enabled = var.environment == "production"
  multi_az_enabled           = var.environment == "production"

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "preferred"

  apply_immediately = true

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-redis"
  })
}

########################################################################################################################
# ElastiCache Redis Monitoring Alarms
########################################################################################################################

# Redis CPU Utilization Alarm
module "redis_cpu_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "~> 3.0"

  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-redis-cpu"
  alarm_description   = "Redis CPU utilization exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 75
  period              = 300
  namespace           = "AWS/ElastiCache"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

# Redis Memory Usage Alarm
module "redis_memory_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "~> 3.0"

  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-redis-memory"
  alarm_description   = "Redis memory usage exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  period              = 300
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

# Redis Network Bytes In Alarm
module "redis_network_in_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "~> 3.0"

  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-redis-network-in"
  alarm_description   = "Redis network bytes in exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 100000000 # 100MB
  period              = 300
  namespace           = "AWS/ElastiCache"
  metric_name         = "NetworkBytesIn"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}
