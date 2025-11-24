resource "aws_cloudwatch_log_group" "worker_log_group" {
  name              = "anysource-worker-logs-${var.project}-${var.environment}"
  retention_in_days = 365

  tags = {
    Name        = "${var.project}-worker-logs"
    Environment = var.environment
    Service     = "worker"
  }
}

locals {
  worker_env_list = [
    for k in sort(keys(local.backend_env_vars)) : {
      name  = k
      value = tostring(local.backend_env_vars[k])
    }
  ]

  worker_secret_list = [
    for k in sort(keys(local.backend_secret_vars)) : {
      name      = k
      valueFrom = local.backend_secret_vars[k]
    }
  ]
}

resource "terraform_data" "worker_image_trigger" {
  input = var.ecr_repositories["worker"]
}

resource "aws_ecs_task_definition" "worker_task" {
  family                   = "${var.project}-worker-${var.environment}"
  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  task_role_arn            = module.roles_micro_services.ecs_task_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_config.cpu
  memory                   = var.worker_config.memory

  lifecycle {
    ignore_changes        = [family]
    create_before_destroy = true
  }

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.ecr_repositories["worker"]
      cpu       = var.worker_config.cpu
      memory    = var.worker_config.memory
      essential = true

      environment = local.worker_env_list

      secrets = local.worker_secret_list

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = var.project
        }
      }
    }
  ])

  depends_on = [
    module.iam,
    aws_cloudwatch_log_group.worker_log_group,
  ]
}

resource "aws_ecs_service" "worker_service" {
  name            = "worker-service"
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.worker_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.worker_config.desired_count

  network_configuration {
    subnets = local.private_subnet_ids
    security_groups = [
      module.ecs.backend_security_group_id
    ]
  }

  depends_on = [
    module.ecs,
    aws_ecs_task_definition.worker_task,
  ]

  tags = {
    Name        = "${var.project}-worker-service"
    Environment = var.environment
    Service     = "worker"
  }
}

resource "aws_appautoscaling_target" "worker_autoscaling" {
  count              = var.worker_config.max_capacity > var.worker_config.min_capacity ? 1 : 0
  max_capacity       = var.worker_config.max_capacity
  min_capacity       = var.worker_config.min_capacity
  resource_id        = "service/${module.ecs.cluster_id}/${aws_ecs_service.worker_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.worker_service]
}

resource "aws_appautoscaling_policy" "worker_cpu_scaling" {
  count              = var.worker_config.max_capacity > var.worker_config.min_capacity ? 1 : 0
  name               = "${var.project}-worker-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker_autoscaling[0].resource_id
  scalable_dimension = aws_appautoscaling_target.worker_autoscaling[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker_autoscaling[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70
  }
}

resource "aws_appautoscaling_policy" "worker_memory_scaling" {
  count              = var.worker_config.max_capacity > var.worker_config.min_capacity ? 1 : 0
  name               = "${var.project}-worker-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker_autoscaling[0].resource_id
  scalable_dimension = aws_appautoscaling_target.worker_autoscaling[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker_autoscaling[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
}
