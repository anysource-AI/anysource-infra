resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project}-${var.environment}-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_cw_log_group" {
  for_each          = toset(var.services_names)
  name              = "${each.key}-logs-${var.environment}"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  for_each                 = var.services_configurations
  family                   = "${var.project}-${each.key}-${var.environment}"
  execution_role_arn       = var.ecs_task_execution_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = each.value.memory
  cpu                      = each.value.cpu

  lifecycle {
    precondition {
      condition     = contains(keys(var.ecr_repositories), each.key)
      error_message = "ECR repository URI not found for service '${each.key}'. Please define '${each.key}' in the ecr_repositories variable to avoid fallback to Docker Hub and potential rate limiting."
    }
    precondition {
      condition     = var.ecr_repositories[each.key] != null && var.ecr_repositories[each.key] != ""
      error_message = "ECR repository URI for service '${each.key}' cannot be null or empty. This prevents fallback to Docker Hub (:latest) which can cause rate limiting and security issues."
    }
    ignore_changes = [family]
  }
  container_definitions = jsonencode(concat(
    each.key == "backend" ? [
      {
        name      = "prestart"
        image     = var.ecr_repositories[each.key]
        cpu       = var.prestart_container_cpu
        memory    = var.prestart_container_memory
        essential = false
        command   = ["bash", "scripts/prestart.sh"]
        environment = concat(
          [
            for key, value in var.env_vars : {
              name  = key
              value = value
            }
          ],
          lookup(each.value, "environment", [])
        ),
        secrets = concat(
          [
            for key, value in var.secret_vars : {
              name      = key
              valueFrom = value
            }
          ],
          lookup(each.value, "secrets", [])
        ),
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "prestart-logs-${var.environment}"
            awslogs-region        = var.region
            awslogs-stream-prefix = var.project
          }
        }
      }
    ] : [],
    [
      {
        name      = each.key
        image     = var.ecr_repositories[each.key]
        cpu       = each.key == "backend" ? each.value.cpu - var.prestart_container_cpu : each.value.cpu
        memory    = each.key == "backend" ? each.value.memory - var.prestart_container_memory : each.value.memory
        essential = true
        dependsOn = each.key == "backend" ? [
          {
            containerName = "prestart"
            condition     = "SUCCESS"
          }
        ] : null
        portMappings = [
          {
            containerPort = each.value.container_port
            hostPort      = each.value.host_port
          }
        ],
        environment = concat(
          [
            for key, value in var.env_vars : {
              name  = key
              value = value
            }
          ],
          lookup(each.value, "environment", [])
        ),
        secrets = concat(
          [
            for key, value in var.secret_vars : {
              name      = key
              valueFrom = value
            }
          ],
          lookup(each.value, "secrets", [])
        ),
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "${each.key}-logs-${var.environment}"
            awslogs-region        = var.region
            awslogs-stream-prefix = var.project
          }
        }
      }
    ]
  ))
}

resource "aws_cloudwatch_log_group" "prestart_cw_log_group" {
  name              = "prestart-logs-${var.environment}"
  retention_in_days = 14
}

resource "aws_ecs_service" "private_service" {
  for_each                          = var.services_configurations
  name                              = "${each.key}-service"
  cluster                           = aws_ecs_cluster.ecs_cluster.id
  task_definition                   = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type                       = "FARGATE"
  desired_count                     = each.value.desired_count
  health_check_grace_period_seconds = each.key == "backend" ? var.health_check_grace_period_seconds : null

  network_configuration {
    subnets = var.private_subnets
    security_groups = [
      each.key == "backend" ? module.sg_backend.security_group_id : module.sg_frontend.security_group_id
    ]
  }

  load_balancer {
    target_group_arn = var.public_alb_target_groups[each.key].arn
    container_name   = each.key
    container_port   = each.value.container_port
  }
}

resource "aws_appautoscaling_target" "service_autoscaling" {
  for_each           = var.services_configurations
  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.desired_count // each.value.min_capacity
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.private_service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_ecs_cluster.ecs_cluster, aws_ecs_service.private_service]
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  for_each           = var.services_configurations
  name               = "${var.project}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_autoscaling[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service_autoscaling[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_autoscaling[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = each.value.memory_auto_scalling_target_value
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  for_each           = var.services_configurations
  name               = "${var.project}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_autoscaling[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service_autoscaling[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_autoscaling[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = each.value.cpu_auto_scalling_target_value
  }
}

module "sg_backend" {
  source      = "../security-group"
  name        = "${var.project}-backend-security-group-sg"
  description = "${var.project}-backend-security-group-sg"
  vpc_id      = var.vpc_id
  ingress_rules = [
    {
      from_port       = var.services_configurations["backend"].container_port
      to_port         = var.services_configurations["backend"].container_port
      protocol        = "tcp"
      cidr_blocks     = [var.vpc_cidr]
      security_groups = []
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "sg_frontend" {
  source      = "../security-group"
  name        = "${var.project}-frontend-security-group-sg"
  description = "${var.project}-frontend-security-group-sg"
  vpc_id      = var.vpc_id
  ingress_rules = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = [var.vpc_cidr]
      security_groups = []
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = [var.vpc_cidr]
      security_groups = []
    }
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
