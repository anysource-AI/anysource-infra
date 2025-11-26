# Directory Sync Scheduled Task for ECS
# This creates a scheduled ECS task that runs directory sync periodically

# CloudWatch Event Rule for scheduling directory sync
resource "aws_cloudwatch_event_rule" "directory_sync" {
  count = var.directory_sync_enabled ? 1 : 0

  name                = "${var.project}-directory-sync-${var.environment}"
  description         = "Trigger directory sync"
  schedule_expression = "rate(${var.directory_sync_interval_minutes} minutes)"
  state               = var.directory_sync_enabled ? "ENABLED" : "DISABLED"

  tags = {
    Name        = "${var.project}-directory-sync-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Log Group for directory sync logs
resource "aws_cloudwatch_log_group" "directory_sync_logs" {
  count = var.directory_sync_enabled ? 1 : 0

  name              = "/ecs/${var.project}-directory-sync-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project}-directory-sync-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Trigger replacement when ECR backend image changes
resource "terraform_data" "directory_sync_image_trigger" {
  count = var.directory_sync_enabled ? 1 : 0

  input = var.ecr_repositories["backend"]
}

# ECS Task Definition for directory sync
resource "aws_ecs_task_definition" "directory_sync" {
  depends_on = [module.iam]
  count      = var.directory_sync_enabled ? 1 : 0

  family                   = "${var.project}-directory-sync-${var.environment}"
  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  tags = {
    Name        = "${var.project}-directory-sync-task-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }

  # Lifecycle management
  lifecycle {
    ignore_changes        = [family, container_definitions]
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.directory_sync_image_trigger[0]]
  }

  # Prevent Terraform from deregistering old task definition revisions
  # This ensures we can rollback to previous versions if needed
  skip_destroy = true

  container_definitions = jsonencode([{
    name    = "directory-sync"
    image   = var.ecr_repositories["backend"]
    command = ["uv", "run", "python", "-m", "app.directory_sync.worker"]
    environment = concat(
      [for k, v in local.backend_env_vars : { name = k, value = tostring(v) }],
      [{ name = "DIRECTORY_SYNC_TIMEOUT_SECONDS", value = "1800" }]
    )
    secrets = [for key, value in local.backend_secret_vars : { name = key, valueFrom = value }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.directory_sync_logs[0].name
        awslogs-region        = var.region
        awslogs-stream-prefix = "directory-sync"
      }
    }
    essential = true
  }])
}

# IAM Role for CloudWatch Events to execute ECS tasks (shared by sync and reconciliation)
resource "aws_iam_role" "events_role" {
  count = (var.directory_sync_enabled || var.directory_reconciliation_enabled) ? 1 : 0

  name = "${var.project}-events-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-events-role-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# IAM Policy for Events Role to run ECS tasks (allows both sync and reconciliation)
resource "aws_iam_role_policy" "events_policy" {
  count = (var.directory_sync_enabled || var.directory_reconciliation_enabled) ? 1 : 0

  name = "${var.project}-events-policy-${var.environment}"
  role = aws_iam_role.events_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = concat(
          var.directory_sync_enabled ? [
            "arn:aws:ecs:${var.region}:*:task-definition/${var.project}-directory-sync-${var.environment}:*"
          ] : [],
          var.directory_reconciliation_enabled ? [
            "arn:aws:ecs:${var.region}:*:task-definition/${var.project}-directory-reconciliation-${var.environment}:*"
          ] : []
        )
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          module.iam.ecs_task_execution_role_arn
        ]
      }
    ]
  })
}

# CloudWatch Event Target - ECS Task
resource "aws_cloudwatch_event_target" "ecs_directory_sync_task" {
  count = var.directory_sync_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.directory_sync[0].name
  target_id = "DirectorySyncTask"
  arn       = module.ecs.ecs_cluster_arn
  role_arn  = aws_iam_role.events_role[0].arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.directory_sync[0].arn_without_revision
    launch_type         = "FARGATE"
    platform_version    = "LATEST"


    # Network configuration (same as backend)
    network_configuration {
      assign_public_ip = false
      subnets          = local.private_subnet_ids
      security_groups  = [module.ecs.backend_security_group_id]
    }

    # Task count and placement
    task_count = 1
  }

  # Retry configuration
  retry_policy {
    maximum_event_age_in_seconds = 3600 # 1 hour
    maximum_retry_attempts       = 3
  }

  depends_on = [module.ecs]
}
