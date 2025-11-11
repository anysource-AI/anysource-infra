# Sentry Relay Service (conditionally deployed in ECS)
# Relay processes telemetry data within customer infrastructure before forwarding to Sentry SaaS
#
# This service is only deployed when valid Sentry Relay credentials are available in WorkOS Vault.
# If credentials are not found, all resources in this file are skipped (count = 0).
# This allows deployments to proceed without Sentry when it's not yet provisioned.

# CloudWatch Logs for Relay
resource "aws_cloudwatch_log_group" "relay" {
  count             = local.deploy_relay ? 1 : 0
  name              = "anysource-relay-logs-${var.project}-${var.environment}"
  retention_in_days = 365

  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = "sentry-relay"
  }
}

# Security group for Relay service
module "sg_relay" {
  count       = local.deploy_relay ? 1 : 0
  source      = "./modules/security-group"
  name        = "${var.project}-relay-security-group"
  description = "Security group for Sentry Relay service"
  vpc_id      = local.vpc_id

  ingress_rules = [
    {
      from_port       = var.sentry_relay_config.container_port
      to_port         = var.sentry_relay_config.container_port
      protocol        = "tcp"
      cidr_blocks     = [var.vpc_cidr] # Allow from VPC (backend can reach relay)
      security_groups = []
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"] # Allow outbound to Sentry SaaS
    }
  ]
}

# ECS Task Definition for Relay
resource "aws_ecs_task_definition" "relay" {
  count                    = local.deploy_relay ? 1 : 0
  family                   = "${var.project}-relay-${var.environment}"
  execution_role_arn       = module.iam.ecs_task_execution_role_arn
  task_role_arn            = module.roles_micro_services.ecs_task_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.sentry_relay_config.cpu
  memory                   = var.sentry_relay_config.memory

  container_definitions = jsonencode([
    {
      name      = "relay"
      image     = "ghcr.io/getsentry/relay:25.10.0"
      cpu       = var.sentry_relay_config.cpu
      memory    = var.sentry_relay_config.memory
      essential = true

      portMappings = [
        {
          containerPort = var.sentry_relay_config.container_port
          hostPort      = var.sentry_relay_config.container_port
          name          = "relay-http"
          appProtocol   = "http"
        }
      ]

      command = ["run"]

      # Relay configuration via environment variables
      # Relay will run in "managed" mode, fetching config from upstream Sentry
      environment = [
        {
          name  = "RELAY_MODE"
          value = "managed"
        },
        {
          name  = "RELAY_UPSTREAM_URL"
          value = var.sentry_relay_upstream
        },
        {
          name  = "RELAY_HOST"
          value = "0.0.0.0"
        },
        {
          name  = "RELAY_PORT"
          value = tostring(var.sentry_relay_config.container_port)
        },
        {
          name  = "RELAY_LOG_LEVEL"
          value = "info"
        },
        {
          name  = "RELAY_LOG_FORMAT"
          value = "json"
        }
      ]

      # Relay credentials from Secrets Manager
      secrets = [
        {
          name      = "RELAY_PUBLIC_KEY"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:SENTRY_RELAY_PUBLIC_KEY::"
        },
        {
          name      = "RELAY_SECRET_KEY"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:SENTRY_RELAY_SECRET_KEY::"
        },
        {
          name      = "RELAY_ID"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:SENTRY_RELAY_ID::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.relay[0].name
          awslogs-region        = var.region
          awslogs-stream-prefix = var.project
        }
      }
    }
  ])

  depends_on = [
    aws_secretsmanager_secret_version.app_secrets
  ]
}

# ECS Service for Relay (internal-only, no ALB)
resource "aws_ecs_service" "relay" {
  count           = local.deploy_relay ? 1 : 0
  name            = "relay-service"
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.relay[0].arn
  launch_type     = "FARGATE"
  desired_count   = var.sentry_relay_config.desired_count

  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [module.sg_relay[0].security_group_id]
  }

  # Enable Service Connect for service discovery
  # This allows backend to reach relay via "relay" hostname
  service_connect_configuration {
    enabled   = true
    namespace = module.ecs.service_connect_namespace_arn
    service {
      port_name      = "relay-http"
      discovery_name = "relay"
      client_alias {
        port     = var.sentry_relay_config.container_port
        dns_name = "relay"
      }
    }
  }

  depends_on = [
    module.ecs
  ]
}

# Auto Scaling for Relay service
resource "aws_appautoscaling_target" "relay" {
  count              = local.deploy_relay ? 1 : 0
  max_capacity       = var.sentry_relay_config.desired_count * 2 # Allow 2x scaling
  min_capacity       = var.sentry_relay_config.desired_count
  resource_id        = "service/${module.ecs.cluster_name}/${aws_ecs_service.relay[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.relay]
}

# CPU-based auto scaling policy
resource "aws_appautoscaling_policy" "relay_cpu" {
  count              = local.deploy_relay ? 1 : 0
  name               = "${var.project}-relay-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.relay[0].resource_id
  scalable_dimension = aws_appautoscaling_target.relay[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.relay[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70
  }
}

# Memory-based auto scaling policy
resource "aws_appautoscaling_policy" "relay_memory" {
  count              = local.deploy_relay ? 1 : 0
  name               = "${var.project}-relay-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.relay[0].resource_id
  scalable_dimension = aws_appautoscaling_target.relay[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.relay[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
}
