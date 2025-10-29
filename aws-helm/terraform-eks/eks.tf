########################################################################################################################
# EKS Cluster
########################################################################################################################

module "eks" {
  count   = var.create_eks ? 1 : 0
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.public_subnet_ids

  # Cluster endpoint configuration
  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_private_access      = var.cluster_endpoint_private_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Additional security group rules
  security_group_additional_rules = merge(
    local.default_cluster_security_group_rules,
    var.cluster_security_group_additional_rules
  )
  node_security_group_additional_rules = merge(
    local.default_node_security_group_rules,
    var.node_security_group_additional_rules
  )

  # Encryption configuration
  create_kms_key                  = var.enable_cluster_encryption
  kms_key_description             = "EKS Secret Encryption Key for ${local.cluster_name}"
  kms_key_deletion_window_in_days = 7
  enable_kms_key_rotation         = true
  kms_key_administrators          = var.kms_key_administrators

  encryption_config = var.enable_cluster_encryption ? {
    resources = ["secrets"]
  } : {}

  addons = local.cluster_addons_with_irsa

  # Enable cluster logging
  enabled_log_types                      = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cloudwatch_log_group_kms_key_id        = null

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    for name, config in var.node_groups : name => {
      name                     = "${local.name_prefix}-${name}"
      iam_role_name            = "${local.name_prefix}-${name}-role"
      iam_role_use_name_prefix = false
      instance_types           = config.instance_types
      min_size                 = config.scaling_config.min_size
      max_size                 = config.scaling_config.max_size
      desired_size             = config.scaling_config.desired_size
      enable_monitoring        = true
      taints                   = config.taints
      update_config            = config.update_config

      labels = merge(config.labels, {
        Environment = var.environment
        NodeGroup   = name
      })

      # IAM role for nodes
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }

      # EBS volume encryption
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = config.disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = merge(local.common_tags, {
        NodeGroup = name
      })
    }
  }

  # Enable irsa
  enable_irsa = true

  # Enable/disable automatic cluster creator admin permissions
  # Set to false when managing access entries explicitly to avoid drift between different IAM identities
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Access entries for API-based access control
  access_entries = var.access_entries

  tags = local.common_tags
}

########################################################################################################################
# EKS ALB Monitoring Alarms
########################################################################################################################

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

########################################################################################################################
# EKS ASG Monitoring Alarms
########################################################################################################################

# Get autoscaling groups for the cluster (only when creating EKS)
# Note: No explicit depends_on to avoid for_each issues when EKS resources change
# The data source will be read after ASGs are created through implicit dependencies
data "aws_autoscaling_groups" "cluster_asgs" {
  count = var.create_eks ? 1 : 0

  filter {
    name   = "tag:eks:cluster-name"
    values = [local.cluster_name]
  }
}

# Create CPU utilization alarm for each ASG in the cluster (only when creating EKS)
# Note: This uses a try() to handle cases where ASG names aren't yet available
resource "aws_cloudwatch_metric_alarm" "asg_cpu_utilization" {
  for_each = var.create_eks ? toset(try(data.aws_autoscaling_groups.cluster_asgs[0].names, [])) : toset([])

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
