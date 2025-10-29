resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project}-${var.environment}-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.service_connect.arn
  }
}

resource "aws_service_discovery_http_namespace" "service_connect" {
  name        = "${var.project}-${var.environment}"
  description = "Service Connect namespace for ${var.project} ${var.environment}"
}

resource "aws_cloudwatch_log_group" "ecs_cw_log_group" {
  for_each          = toset(var.services_names)
  name              = "anysource-${each.key}-logs-${var.project}-${var.environment}"
  retention_in_days = 365
}

# Trigger replacement when ECR image changes
resource "terraform_data" "image_trigger" {
  for_each = var.services_configurations

  input = var.ecr_repositories[each.key]
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  for_each                 = var.services_configurations
  family                   = "${var.project}-${each.key}-${var.environment}"
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
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
    ignore_changes        = [family, container_definitions]
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.image_trigger[each.key]]
  }

  # Prevent Terraform from deregistering old task definition revisions
  # This ensures we can rollback to previous versions if needed
  skip_destroy = true
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
            for key, value in var.backend_env_vars : {
              name  = key
              value = value
            }
          ],
          lookup(each.value, "environment", [])
        ),
        secrets = concat(
          [
            for key, value in var.backend_secret_vars : {
              name      = key
              valueFrom = value
            }
          ],
          lookup(each.value, "secrets", [])
        ),
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "anysource-prestart-logs-${var.project}-${var.environment}"
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
            name          = "http"
            appProtocol   = "http"
          }
        ],
        environment = concat(
          [
            for key, value in(each.key == "backend" ? var.backend_env_vars : var.frontend_env_vars) : {
              name  = key
              value = value
            }
          ],
          lookup(each.value, "environment", [])
        ),
        secrets = concat(
          [
            for key, value in(each.key == "backend" ? var.backend_secret_vars : {}) : {
              name      = key
              valueFrom = value
            }
          ],
          lookup(each.value, "secrets", [])
        ),
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "anysource-${each.key}-logs-${var.project}-${var.environment}"
            awslogs-region        = var.region
            awslogs-stream-prefix = var.project
          }
        }
      }
    ]
  ))
}

resource "aws_cloudwatch_log_group" "prestart_cw_log_group" {
  name              = "anysource-prestart-logs-${var.project}-${var.environment}"
  retention_in_days = 365
}

resource "aws_ecs_service" "private_service" {
  for_each                          = var.services_configurations
  name                              = "${each.key}-service"
  cluster                           = aws_ecs_cluster.ecs_cluster.id
  task_definition                   = aws_ecs_task_definition.ecs_task_definition[each.key].arn
  launch_type                       = "FARGATE"
  desired_count                     = each.value.desired_count
  health_check_grace_period_seconds = each.key == "backend" ? var.health_check_grace_period_seconds : null
  enable_execute_command            = each.key == "backend" ? var.enable_ecs_exec : false

  depends_on = [
    aws_ecs_cluster.ecs_cluster,
    aws_service_discovery_http_namespace.service_connect
  ]

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

  dynamic "service_connect_configuration" {
    for_each = each.key == "backend" ? [1] : []
    content {
      enabled = true
      service {
        port_name      = "http"
        discovery_name = var.services_configurations["backend"].name
        client_alias {
          port     = each.value.container_port
          dns_name = var.services_configurations["backend"].name
        }
        timeout {
          idle_timeout_seconds        = 300 # 5 minutes
          per_request_timeout_seconds = 300 # 5 minutes
        }
      }
    }
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
