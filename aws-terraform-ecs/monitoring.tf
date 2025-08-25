# Local variables for monitoring
locals {
  # Use Chatbot for enterprise alerting - much simpler than SNS
  alarm_actions = var.enable_chatbot_alerts ? [aws_sns_topic.chatbot_topic[0].arn] : []
  # Only create alarms for services when monitoring is enabled
  monitored_services = var.enable_monitoring ? var.services_configurations : {}
}

# CloudWatch Alarms for ECS Services
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  for_each            = local.monitored_services
  alarm_name          = "${var.project}-${var.environment}-${each.key}-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ecs cpu utilization"
  alarm_actions       = local.alarm_actions

  dimensions = {
    ServiceName = "${each.key}-service"
    ClusterName = "${var.project}-${var.environment}-cluster"
  }

  depends_on = [module.ecs]
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  for_each            = local.monitored_services
  alarm_name          = "${var.project}-${var.environment}-${each.key}-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ecs memory utilization"
  alarm_actions       = local.alarm_actions

  dimensions = {
    ServiceName = "${each.key}-service"
    ClusterName = "${var.project}-${var.environment}-cluster"
  }

  depends_on = [module.ecs]
}

# RDS CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS cpu utilization"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-database-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_config["FreeableMemory"].period
  statistic           = "Average"
  threshold           = var.rds_alarm_config["FreeableMemory"].threshold
  unit                = var.rds_alarm_config["FreeableMemory"].unit
  alarm_description   = "Alarm when RDS FreeableMemory is low"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

resource "aws_cloudwatch_metric_alarm" "rds_disk_queue_depth" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-disk-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_config["DiskQueueDepth"].period
  statistic           = "Average"
  threshold           = var.rds_alarm_config["DiskQueueDepth"].threshold
  unit                = var.rds_alarm_config["DiskQueueDepth"].unit
  alarm_description   = "Alarm when RDS DiskQueueDepth is high"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

resource "aws_cloudwatch_metric_alarm" "rds_write_iops" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-write-iops"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteIOPS"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_config["WriteIOPS"].period
  statistic           = "Average"
  threshold           = var.rds_alarm_config["WriteIOPS"].threshold
  unit                = var.rds_alarm_config["WriteIOPS"].unit
  alarm_description   = "Alarm when RDS WriteIOPS is high"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

resource "aws_cloudwatch_metric_alarm" "rds_read_iops" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-read-iops"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadIOPS"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_config["ReadIOPS"].period
  statistic           = "Average"
  threshold           = var.rds_alarm_config["ReadIOPS"].threshold
  unit                = var.rds_alarm_config["ReadIOPS"].unit
  alarm_description   = "Alarm when RDS ReadIOPS is high"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  for_each            = var.enable_monitoring ? local.db_config : {}
  alarm_name          = "${var.project}-${var.environment}-rds-${each.key}-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.rds_alarm_config["Storage"].period
  statistic           = "Average"
  threshold           = var.rds_alarm_config["Storage"].threshold
  unit                = var.rds_alarm_config["Storage"].unit
  alarm_description   = "Alarm when RDS storage is low"
  alarm_actions       = local.alarm_actions

  dimensions = {
    DBClusterIdentifier = module.rds[each.key].cluster_identifier
  }

  depends_on = [module.rds]
}

# Redis CloudWatch Alarms - Dynamic for multiple clusters
resource "aws_cloudwatch_metric_alarm" "redis_cpu_utilization" {
  count               = var.enable_monitoring ? aws_elasticache_replication_group.redis.num_cache_clusters : 0
  alarm_name          = "${var.project}-${var.environment}-redis-cpu-utilization-${format("%03d", count.index + 1)}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache cpu utilization for cluster node ${format("%03d", count.index + 1)}"
  alarm_actions       = local.alarm_actions

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis.replication_group_id}-${format("%03d", count.index + 1)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_utilization" {
  count               = var.enable_monitoring ? aws_elasticache_replication_group.redis.num_cache_clusters : 0
  alarm_name          = "${var.project}-${var.environment}-redis-memory-utilization-${format("%03d", count.index + 1)}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ElastiCache memory utilization for cluster node ${format("%03d", count.index + 1)}"
  alarm_actions       = local.alarm_actions

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis.replication_group_id}-${format("%03d", count.index + 1)}"
  }
}

# ALB Target Health Alarms
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  for_each            = local.monitored_services
  alarm_name          = "${var.project}-${var.environment}-alb-${each.key}-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = local.alarm_actions

  dimensions = {
    LoadBalancer = module.private_alb.alb_arn_suffix
    TargetGroup  = module.private_alb.target_groups[each.key].arn_suffix
  }

  depends_on = [module.private_alb]
}

# ALB 5XX Error Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project}-alb-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.alb_5xx_alarm_period
  statistic           = "Sum"
  threshold           = var.alb_5xx_alarm_threshold
  alarm_description   = "Alarm when the ALB returns 5XX errors"
  dimensions = {
    LoadBalancer = module.private_alb.alb_arn_suffix
  }
  treat_missing_data = "notBreaching"
  actions_enabled    = false
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  for_each            = local.monitored_services
  alarm_name          = "${var.project}-${var.environment}-alb-${each.key}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors ALB unhealthy targets"
  alarm_actions       = local.alarm_actions

  dimensions = {
    LoadBalancer = module.private_alb.alb_arn_suffix
    TargetGroup  = module.private_alb.target_groups[each.key].arn_suffix
  }

  depends_on = [module.private_alb]
}

# AWS Chatbot Integration (Much simpler than SNS for enterprise)
resource "aws_sns_topic" "chatbot_topic" {
  count             = var.enable_chatbot_alerts ? 1 : 0
  name              = "${var.project}-${var.environment}-chatbot-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project}-${var.environment}-chatbot-alerts"
    Environment = var.environment
  }
}

# Chatbot configuration for Slack (requires manual setup in AWS Console)
resource "aws_chatbot_slack_channel_configuration" "alerts" {
  count              = var.enable_chatbot_alerts && var.slack_channel_id != "" ? 1 : 0
  configuration_name = "${var.project}-${var.environment}-alerts"
  iam_role_arn       = aws_iam_role.chatbot_role[0].arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_team_id
  sns_topic_arns     = [aws_sns_topic.chatbot_topic[0].arn]

  logging_level = "ERROR"
}

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# IAM role for Chatbot
resource "aws_iam_role" "chatbot_role" {
  count = var.enable_chatbot_alerts ? 1 : 0
  name  = "${var.project}-${var.environment}-chatbot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:chatbot::${data.aws_caller_identity.current.account_id}:chat-configuration/slack-channel/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "chatbot_policy" {
  count      = var.enable_chatbot_alerts ? 1 : 0
  role       = aws_iam_role.chatbot_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}
