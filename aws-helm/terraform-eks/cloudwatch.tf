
# List all ALBs with the cluster tag
data "aws_lbs" "all" {
  tags = {
    "elbv2.k8s.aws/cluster" = local.cluster_name
  }
}

# Conditionally create the ALB data source if any exist
data "aws_lb" "alb" {
  count = length(tolist(data.aws_lbs.all.arns)) > 0 ? 1 : 0
  arn   = length(tolist(data.aws_lbs.all.arns)) > 0 ? tolist(data.aws_lbs.all.arns)[0] : null
}

module "alb_5xx_metric_alarms" {
  source   = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version  = "~> 3.0"
  for_each = { for idx, alb in data.aws_lb.alb : idx => alb if alb.name != null }

  alarm_name          = "${each.value.name}-5xx-errors"
  alarm_description   = "ALB 5xx errors exceed threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold
  period              = var.alb_alarm_period
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.name
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

module "alb_unhealthy_host_count_alarm" {
  source   = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version  = "~> 3.0"
  for_each = { for idx, alb in data.aws_lb.alb : idx => alb if alb.name != null }

  alarm_name          = "${each.value.name}-unhealthy-host-count"
  alarm_description   = "ALB UnHealthyHostCount exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alb_unhealthy_evaluation_periods
  threshold           = var.alb_unhealthy_threshold
  period              = var.alb_alarm_period
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.name
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

module "alb_latency_alarm" {
  source   = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version  = "~> 3.0"
  for_each = { for idx, alb in data.aws_lb.alb : idx => alb if alb.name != null }

  alarm_name          = "${each.value.name}-latency"
  alarm_description   = "ALB TargetResponseTime exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alb_latency_evaluation_periods
  threshold           = var.alb_latency_threshold
  period              = var.alb_alarm_period
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.name
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}

# Get autoscaling groups for the cluster
data "aws_autoscaling_groups" "cluster_asgs" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [local.cluster_name]
  }
}

# Create CPU utilization alarm for each ASG in the cluster
resource "aws_cloudwatch_metric_alarm" "asg_cpu_utilization" {
  for_each = toset(data.aws_autoscaling_groups.cluster_asgs.names)

  alarm_name          = "${each.key}-cpu-utilization"
  alarm_description   = "ASG ${each.key} CPUUtilization exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asg_cpu_evaluation_periods
  threshold           = var.asg_cpu_threshold
  period              = var.asg_cpu_alarm_period
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = each.key
  }

  alarm_actions             = []
  ok_actions                = []
  insufficient_data_actions = []
}
