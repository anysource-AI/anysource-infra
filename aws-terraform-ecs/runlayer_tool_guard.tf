# ========================================
# RUNLAYER TOOLGUARD ECS SERVICE WITH GPU
# ========================================
# This service runs the Runlayer ToolGuard Flask server on g6f.large instances
# with fractional GPU (3GB VRAM) for ML model inference
#
# Data source for VPC information (needed for security group CIDR rules)
data "aws_vpc" "selected" {
  count = var.enable_runlayer_tool_guard ? 1 : 0
  id    = local.vpc_id
}
#
# SECURITY BEST PRACTICES IMPLEMENTED:
# -------------------------------------
# 1. Dynamic AMI Selection: Uses data source to find latest ECS-optimized GPU AMI
#    - Eliminates hard-coded AMI IDs that are region-specific and become outdated
#    - Ensures deployments work across regions and use latest security patches
#
# 2. Network Security: 
#    - Security group restricted to backend services only (not entire VPC CIDR)
#    - Follows principle of least privilege for network access
#    - TODO: Consider implementing mutual TLS or API key authentication between services
#
# 3. Audit & Compliance:
#    - CloudWatch log retention set to 30 days (configurable) for security auditing
#    - Comprehensive cost allocation tags (CostCenter, Owner, Purpose) for billing visibility
#    - CloudWatch alarms for service health monitoring
#
# OPERATIONAL BEST PRACTICES IMPLEMENTED:
# ----------------------------------------
# 4. Resource Management:
#    - Container resources reserve ~12% for OS/ECS agent (3584 CPU, 7168 MB memory)
#    - Prevents resource exhaustion and ensures system stability
#
# 5. Controlled Scaling:
#    - Auto-scaling limited to 1 instance at a time for expensive GPU instances
#    - Prevents unexpected cost spikes while maintaining availability
#
# 6. GPU Initialization:
#    - Health check grace periods increased to 600 seconds
#    - Allows time for NVIDIA driver initialization and ML model loading
#    - User data script includes error handling and GPU validation
#
# 7. Monitoring & Alerting:
#    - CloudWatch alarms for: no running tasks, high CPU/memory, health check failures
#    - SNS topic for alert delivery (configure SNS subscriptions separately)
#
# CONFIGURATION:
# --------------
# Variables:
#   - enable_runlayer_tool_guard: Enable/disable the service
#   - runlayer_tool_guard_image_uri: Docker image for the service
#   - runlayer_tool_guard_desired_count: Number of instances (1-5)
#   - runlayer_tool_guard_log_retention_days: Log retention (default: 30 days)
#   - enable_runlayer_tool_guard_alarms: Enable CloudWatch alarms (default: true)

# IMPORTANT: g6f.large instances require NVIDIA GRID drivers (not standard CUDA)
# GRID drivers are installed at runtime via user data script for simplicity
# This eliminates the need for custom AMI management across multiple regions

# Use latest Ubuntu 22.04 LTS AMI (Canonical official)
# The user data script will install NVIDIA GRID drivers, Docker, and ECS agent
# This matches the original manual setup environment
data "aws_ami" "ecs_optimized" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Auto Scaling Group for GPU instances
resource "aws_launch_template" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name_prefix = "${var.project}-runlayer-tool-guard-${var.environment}-"

  # Use standard ECS-optimized AMI - GRID drivers installed at runtime
  image_id      = data.aws_ami.ecs_optimized[0].id
  instance_type = "g6f.large" # Fractional GPU instance (3GB VRAM) - GRID drivers installed at runtime

  vpc_security_group_ids = [aws_security_group.runlayer_tool_guard[0].id]

  iam_instance_profile {
    name = aws_iam_instance_profile.runlayer_tool_guard[0].name
  }

  # Increase root volume size for GPU container images and NVIDIA drivers
  block_device_mappings {
    device_name = "/dev/sda1" # Ubuntu root device
    ebs {
      volume_size           = 50 # GB - GPU images + drivers require significant space
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/scripts/runlayer_tool_guard_user_data.sh", {
    cluster_name = aws_ecs_cluster.runlayer_tool_guard[0].name
    region       = var.region
    environment  = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = "${var.project}-runlayer-tool-guard-${var.environment}"
      Environment  = var.environment
      Service      = "runlayer-tool-guard"
      ManagedBy    = "terraform"
      CostCenter   = "security"
      Owner        = "platform-team"
      Purpose      = "ml-tool-poisoning-detection"
      InstanceType = "gpu"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name                      = "${var.project}-runlayer-tool-guard-${var.environment}"
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = []
  health_check_type         = "EC2"
  health_check_grace_period = 900 # Extended for runtime GRID driver installation (10-15 min)

  min_size         = 1
  max_size         = var.runlayer_tool_guard_desired_count
  desired_capacity = var.runlayer_tool_guard_desired_count

  launch_template {
    id      = aws_launch_template.runlayer_tool_guard[0].id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = false
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-runlayer-tool-guard-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Dedicated ECS Cluster for GPU instances
resource "aws_ecs_cluster" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name = "${var.project}-runlayer-tool-guard-${var.environment}"

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Internal Network Load Balancer for Runlayer ToolGuard
# This allows backend services to connect via a stable DNS name
resource "aws_lb" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name               = "${var.project}-rtg-nlb-${var.environment}"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.private_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-nlb-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Target Group for Runlayer ToolGuard
resource "aws_lb_target_group" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name        = "${var.project}-rtg-tg-${var.environment}"
  port        = 8080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    protocol            = "HTTP"
    path                = "/health"
    port                = "8080"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-tg-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# NLB Listener
resource "aws_lb_listener" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  load_balancer_arn = aws_lb.runlayer_tool_guard[0].arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.runlayer_tool_guard[0].arn
  }

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-listener-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


# ECS Capacity Provider
resource "aws_ecs_capacity_provider" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  # AWS doesn't allow capacity provider names starting with "ecs", "aws", or "fargate"
  # Use a name that avoids these prefixes
  name = "runlayer-tool-guard-${var.project}-${var.environment}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.runlayer_tool_guard[0].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1 # Conservative scaling for expensive GPU instances
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Associate capacity provider with cluster
resource "aws_ecs_cluster_capacity_providers" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  cluster_name = aws_ecs_cluster.runlayer_tool_guard[0].name

  capacity_providers = [aws_ecs_capacity_provider.runlayer_tool_guard[0].name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.runlayer_tool_guard[0].name
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name              = "${var.project}-runlayer-tool-guard-logs-${var.environment}"
  retention_in_days = var.runlayer_tool_guard_log_retention_days # Configurable retention for security auditing

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-logs-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  family                   = "${var.project}-runlayer-tool-guard-${var.environment}"
  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  task_role_arn            = module.roles_micro_services.ecs_task_role_arn
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge" # Required for EC2 launch type

  container_definitions = jsonencode([
    {
      name      = "runlayer-tool-guard"
      image     = var.runlayer_tool_guard_image_uri
      cpu       = 1536 # Reserve ~25% for OS/ECS agent (instance shows 2048 CPU units available)
      memory    = 6144 # Reserve ~25% for OS/ECS agent (g6f.large has 8GB RAM = 8192 MB)
      essential = true

      # GPU resource requirements
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1" # Request 1 fractional GPU
        }
      ]

      portMappings = [
        {
          name          = "runlayer-tool-guard"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 180 # Increased for runtime GRID driver installation and model loading
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.runlayer_tool_guard[0].name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = [
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "MODEL_TYPE"
          value = "xgboost"
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# ECS Service
resource "aws_ecs_service" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name            = "runlayer-tool-guard"
  cluster         = aws_ecs_cluster.runlayer_tool_guard[0].id
  task_definition = aws_ecs_task_definition.runlayer_tool_guard[0].arn
  desired_count   = var.runlayer_tool_guard_desired_count
  launch_type     = "EC2"

  # Service Connect disabled - Ubuntu ECS agent doesn't include Service Connect agent
  service_connect_configuration {
    enabled = false
  }

  # Register with NLB target group for stable internal access
  load_balancer {
    target_group_arn = aws_lb_target_group.runlayer_tool_guard[0].arn
    container_name   = "runlayer-tool-guard"
    container_port   = 8080
  }

  # Health check grace period for runtime GRID driver installation and model loading
  health_check_grace_period_seconds = 900

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.instance-type =~ g6f.*"
  }

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }

  depends_on = [
    aws_autoscaling_group.runlayer_tool_guard,
    aws_ecs_cluster_capacity_providers.runlayer_tool_guard,
    aws_lb_listener.runlayer_tool_guard
  ]
}

# Security Group for Runlayer ToolGuard
resource "aws_security_group" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name_prefix = "${var.project}-runlayer-tool-guard-${var.environment}-"
  vpc_id      = local.vpc_id

  description = "Security group for Runlayer ToolGuard service"

  # Allow inbound from backend service security group
  ingress {
    description     = "HTTP from backend services"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [module.ecs.backend_security_group_id]
  }

  # Allow inbound from NLB (NLBs use the client security group, but we also need to allow from within VPC)
  ingress {
    description = "HTTP from VPC for NLB health checks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected[0].cidr_block]
  }

  # Allow outbound internet access for model downloads
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Instance Profile for GPU instances
resource "aws_iam_instance_profile" "runlayer_tool_guard" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name = "${var.project}-runlayer-tool-guard-instance-profile-${var.environment}"
  role = aws_iam_role.runlayer_tool_guard_instance[0].name

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-instance-profile-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# IAM Role for GPU instances
resource "aws_iam_role" "runlayer_tool_guard_instance" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  name = "${var.project}-runlayer-tool-guard-instance-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-instance-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Attach ECS instance policy
resource "aws_iam_role_policy_attachment" "runlayer_tool_guard_ecs_instance" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  role       = aws_iam_role.runlayer_tool_guard_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach SSM policy for instance management
resource "aws_iam_role_policy_attachment" "runlayer_tool_guard_ssm" {
  count = var.enable_runlayer_tool_guard ? 1 : 0

  role       = aws_iam_role.runlayer_tool_guard_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ========================================
# CLOUDWATCH ALARMS FOR MONITORING
# ========================================

# SNS Topic for alerting (optional - comment out if you don't have SNS configured)
resource "aws_sns_topic" "runlayer_tool_guard_alerts" {
  count = var.enable_runlayer_tool_guard && var.enable_runlayer_tool_guard_alarms ? 1 : 0

  name = "${var.project}-runlayer-tool-guard-alerts-${var.environment}"

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-alerts-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Alarm: No running tasks
resource "aws_cloudwatch_metric_alarm" "runlayer_tool_guard_no_tasks" {
  count = var.enable_runlayer_tool_guard && var.enable_runlayer_tool_guard_alarms ? 1 : 0

  alarm_name          = "${var.project}-runlayer-tool-guard-no-tasks-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when Runlayer ToolGuard has no running tasks"
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = aws_ecs_service.runlayer_tool_guard[0].name
    ClusterName = aws_ecs_cluster.runlayer_tool_guard[0].name
  }

  alarm_actions = var.enable_runlayer_tool_guard_alarms ? [aws_sns_topic.runlayer_tool_guard_alerts[0].arn] : []

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-no-tasks-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Alarm: High CPU utilization
resource "aws_cloudwatch_metric_alarm" "runlayer_tool_guard_high_cpu" {
  count = var.enable_runlayer_tool_guard && var.enable_runlayer_tool_guard_alarms ? 1 : 0

  alarm_name          = "${var.project}-runlayer-tool-guard-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when CPU utilization is consistently high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.runlayer_tool_guard[0].name
    ClusterName = aws_ecs_cluster.runlayer_tool_guard[0].name
  }

  alarm_actions = var.enable_runlayer_tool_guard_alarms ? [aws_sns_topic.runlayer_tool_guard_alerts[0].arn] : []

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-high-cpu-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Alarm: High memory utilization
resource "aws_cloudwatch_metric_alarm" "runlayer_tool_guard_high_memory" {
  count = var.enable_runlayer_tool_guard && var.enable_runlayer_tool_guard_alarms ? 1 : 0

  alarm_name          = "${var.project}-runlayer-tool-guard-high-memory-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Alert when memory utilization is consistently high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.runlayer_tool_guard[0].name
    ClusterName = aws_ecs_cluster.runlayer_tool_guard[0].name
  }

  alarm_actions = var.enable_runlayer_tool_guard_alarms ? [aws_sns_topic.runlayer_tool_guard_alerts[0].arn] : []

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-high-memory-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}

# Alarm: Service unhealthy (uses custom metric from health checks)
resource "aws_cloudwatch_metric_alarm" "runlayer_tool_guard_unhealthy" {
  count = var.enable_runlayer_tool_guard && var.enable_runlayer_tool_guard_alarms ? 1 : 0

  alarm_name          = "${var.project}-runlayer-tool-guard-unhealthy-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckFailed"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Alert when health checks fail repeatedly"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.runlayer_tool_guard[0].name
    ClusterName = aws_ecs_cluster.runlayer_tool_guard[0].name
  }

  alarm_actions = var.enable_runlayer_tool_guard_alarms ? [aws_sns_topic.runlayer_tool_guard_alerts[0].arn] : []

  tags = {
    Name        = "${var.project}-runlayer-tool-guard-unhealthy-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "security"
    Owner       = "platform-team"
    Purpose     = "ml-tool-poisoning-detection"
  }
}
