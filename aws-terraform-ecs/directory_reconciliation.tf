# Directory Reconciliation Scheduled Task for ECS
# This creates a scheduled ECS task that runs full directory reconciliation periodically

# CloudWatch Event Rule for scheduling directory reconciliation
resource "aws_cloudwatch_event_rule" "directory_reconciliation" {
  count = var.directory_reconciliation_enabled ? 1 : 0

  name                = "${var.project}-directory-reconciliation-${var.environment}"
  description         = "Trigger directory reconciliation (full state sync)"
  schedule_expression = var.directory_reconciliation_schedule
  state               = var.directory_reconciliation_enabled ? "ENABLED" : "DISABLED"

  tags = {
    Name        = "${var.project}-directory-reconciliation-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Log Group for directory reconciliation logs
resource "aws_cloudwatch_log_group" "directory_reconciliation_logs" {
  count = var.directory_reconciliation_enabled ? 1 : 0

  name              = "/ecs/${var.project}-directory-reconciliation-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project}-directory-reconciliation-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Trigger replacement when ECR backend image changes
resource "terraform_data" "directory_reconciliation_image_trigger" {
  count = var.directory_reconciliation_enabled ? 1 : 0

  input = var.ecr_repositories["backend"]
}

# ECS Task Definition for directory reconciliation
resource "aws_ecs_task_definition" "directory_reconciliation" {
  depends_on = [module.iam]
  count      = var.directory_reconciliation_enabled ? 1 : 0

  family                   = "${var.project}-directory-reconciliation-${var.environment}"
  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  tags = {
    Name        = "${var.project}-directory-reconciliation-task-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }

  # Lifecycle management
  lifecycle {
    ignore_changes        = [family, container_definitions]
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.directory_reconciliation_image_trigger[0]]
  }

  # Prevent Terraform from deregistering old task definition revisions
  # This ensures we can rollback to previous versions if needed
  skip_destroy = true

  container_definitions = jsonencode([{
    name    = "directory-reconciliation"
    image   = var.ecr_repositories["backend"]
    command = ["uv", "run", "python", "-m", "app.directory_sync.worker", "--task", "reconcile"]
    environment = concat(
      [for k, v in local.backend_env_vars : { name = k, value = tostring(v) }],
      [{ name = "DIRECTORY_SYNC_TIMEOUT_SECONDS", value = "3600" }]
    )
    secrets = [for key, value in local.backend_secret_vars : { name = key, valueFrom = value }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.directory_reconciliation_logs[0].name
        awslogs-region        = var.region
        awslogs-stream-prefix = "directory-reconciliation"
      }
    }
    essential = true
  }])
}

# CloudWatch Event Target - ECS Task
resource "aws_cloudwatch_event_target" "ecs_directory_reconciliation_task" {
  count = var.directory_reconciliation_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.directory_reconciliation[0].name
  target_id = "DirectoryReconciliationTask"
  arn       = module.ecs.ecs_cluster_arn
  role_arn  = aws_iam_role.events_role[0].arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.directory_reconciliation[0].arn_without_revision
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
    maximum_event_age_in_seconds = 7200 # 2 hours (reconciliation may take longer)
    maximum_retry_attempts       = 3
  }

  depends_on = [module.ecs]
}

