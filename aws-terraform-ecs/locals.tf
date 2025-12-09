# Shared locals for consistent logic across modules
locals {
  # Default application images for Runlayer services
  # NOTE: default_app_version is updated automatically by CI
  default_app_version = "1.14.1"

  app_version = coalesce(var.app_version, local.default_app_version)

  default_ecr_repositories = {
    backend  = "public.ecr.aws/anysource/anysource-api:${local.app_version}"
    frontend = "public.ecr.aws/anysource/anysource-web:${local.app_version}"
    worker   = "public.ecr.aws/anysource/anysource-worker:${local.app_version}"
  }

  ecr_repositories = var.ecr_repositories != null ? var.ecr_repositories : local.default_ecr_repositories

  image_tags = {
    for svc, uri in local.ecr_repositories :
    svc => (
      length(regexall("@", uri)) > 0
      ? split("@", uri)[1]          # digest case
      : reverse(split(":", uri))[0] # tag is the last colon segment
    )
  }

  backend_image_tag  = local.image_tags.backend
  frontend_image_tag = local.image_tags.frontend
  worker_image_tag   = local.image_tags.worker

  # VPC and subnet references - use existing VPC if provided, otherwise use created VPC
  vpc_id             = var.existing_vpc_id != null ? var.existing_vpc_id : module.vpc[0].vpc_id
  private_subnet_ids = var.existing_vpc_id != null ? var.existing_private_subnet_ids : module.vpc[0].private_subnets
  public_subnet_ids  = var.existing_vpc_id != null ? var.existing_public_subnet_ids : module.vpc[0].public_subnets

  app_url              = "https://${var.domain_name}"
  backend_cors_origins = length(var.backend_cors_origins) > 0 ? join(",", var.backend_cors_origins) : ""
  # Deployment identification - customer_id defaults to domain name
  customer_id = var.customer_id != "" ? var.customer_id : var.domain_name

  # Runlayer ToolGuard internal endpoint URL (uses NLB DNS name)
  # NLB provides automatic DNS name, no custom Route53 zone needed
  runlayer_tool_guard_endpoint_url = var.enable_runlayer_tool_guard ? "http://${aws_lb.runlayer_tool_guard[0].dns_name}:8080" : null

  # Backend-specific environment variables (non-sensitive)
  backend_env_vars = merge({
    ENVIRONMENT          = var.environment
    API_V1_STR           = "/api/v1"
    POSTGRES_SERVER      = module.rds[var.database_name].cluster_endpoint
    POSTGRES_PORT        = "5432"
    POSTGRES_DB          = var.database_name
    POSTGRES_USER        = var.database_username
    POSTGRES_SSL_MODE    = var.database_config.force_ssl == 1 ? "require" : "prefer"
    REDIS_URL            = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0"
    APP_URL              = local.app_url
    AUTH_CLIENT_ID       = var.auth_client_id
    BACKEND_CORS_ORIGINS = local.backend_cors_origins
    WORKERS              = var.workers
    # AWS region for Bedrock and other AWS services
    AWS_REGION = var.region
    # Bedrock Guardrail for prompt attack detection
    BEDROCK_GUARDRAIL_ARN = aws_bedrock_guardrail.guardrail.guardrail_arn
    # Database connection pool settings
    DB_POOL_SIZE     = var.database_config.pool_size
    DB_MAX_OVERFLOW  = var.database_config.max_overflow
    DB_POOL_TIMEOUT  = var.database_config.pool_timeout
    DB_POOL_RECYCLE  = var.database_config.pool_recycle
    DB_POOL_PRE_PING = var.database_config.pool_pre_ping
    # Tokenizers configuration for LlamaFirewall parallel processing
    TOKENIZERS_PARALLELISM = "true"
    # OAuth Broker URL
    OAUTH_BROKER_URL = var.oauth_broker_url
    # Deployment identification for telemetry (deployment_type: ecs or eks)
    CUSTOMER_ID     = local.customer_id
    DEPLOYMENT_TYPE = "ecs"
    # Application version from image tag for release tracking in Sentry
    APP_VERSION = local.backend_image_tag
    # Allow infra version to be omitted; backend will default to APP_VERSION at runtime
    INFRA_VERSION = var.infra_version
    # Sentry Relay Host - Backend will replace host:port in SENTRY_DSN
    # Derived from relay service configuration (Service Connect DNS name + port)
    # Only set if relay is deployed, otherwise empty to use direct Sentry DSN
    SENTRY_RELAY_HOST = local.deploy_relay ? "relay:${var.sentry_relay_config.container_port}" : ""
    # RunLayer Deploy Infrastructure Configuration
    # Conditionally set RUNLAYER_DEPLOY based on enable_runlayer_deploy variable
    RUNLAYER_DEPLOY                                  = var.enable_runlayer_deploy ? "ECS" : ""
    RUNLAYER_DEPLOY_STATE_BUCKET                     = aws_s3_bucket.terraform_state.id
    RUNLAYER_DEPLOY_ECS_CLUSTER_ARN                  = module.ecs.ecs_cluster_arn
    RUNLAYER_DEPLOY_VPC_ID                           = local.vpc_id
    RUNLAYER_DEPLOY_PRIVATE_SUBNET_IDS               = jsonencode(local.private_subnet_ids)
    RUNLAYER_DEPLOY_TASK_EXECUTION_ROLE_ARN          = module.iam.ecs_task_execution_role_arn
    RUNLAYER_DEPLOY_SERVICE_DISCOVERY_NAMESPACE_ID   = aws_service_discovery_private_dns_namespace.deployments.id
    RUNLAYER_DEPLOY_SERVICE_DISCOVERY_NAMESPACE_NAME = aws_service_discovery_private_dns_namespace.deployments.name
    RUNLAYER_DEPLOY_VPC_CIDR                         = var.vpc_cidr
    RUNLAYER_DEPLOY_REGION                           = var.region
    RUNLAYER_DEPLOY_CUSTOM_IMAGES_ECR_REPO_URL       = aws_ecr_repository.custom_images.repository_url
    },
    local.runlayer_tool_guard_endpoint_url != null ? {
      # Runlayer ToolGuard endpoint configuration (only set when enabled)
      RUNLAYER_TOOL_GUARD_ENDPOINT_URL = local.runlayer_tool_guard_endpoint_url
      RUNLAYER_TOOL_GUARD_TIMEOUT      = tostring(var.runlayer_tool_guard_timeout)
    } : {}
  )

  # Backend-specific secrets from AWS Secrets Manager
  backend_secret_vars = {
    POSTGRES_PASSWORD = "${aws_secretsmanager_secret.app_secrets.arn}:PLATFORM_DB_PASSWORD::"
    SECRET_KEY        = "${aws_secretsmanager_secret.app_secrets.arn}:SECRET_KEY::"
    MASTER_SALT       = "${aws_secretsmanager_secret.app_secrets.arn}:MASTER_SALT::"
    SENTRY_DSN        = "${aws_secretsmanager_secret.app_secrets.arn}:SENTRY_DSN::"
    AUTH_API_KEY      = "${aws_secretsmanager_secret.app_secrets.arn}:AUTH_API_KEY::"
  }

  # Frontend-specific environment variables (non-sensitive)
  frontend_env_vars = {
    PUBLIC_AUTH_CLIENT_ID   = var.auth_client_id
    PUBLIC_APP_URL          = local.app_url
    PUBLIC_BACKEND_URL      = local.app_url
    PUBLIC_BACKEND_VERSION  = local.backend_image_tag
    PUBLIC_WEBAPP_VERSION   = local.frontend_image_tag
    PUBLIC_WORKER_VERSION   = local.worker_image_tag
    PUBLIC_VERSION_URL      = var.version_url
    PUBLIC_OAUTH_BROKER_URL = var.oauth_broker_url
    # Conditionally set PUBLIC_RUNLAYER_DEPLOY based on enable_runlayer_deploy variable
    PUBLIC_RUNLAYER_DEPLOY = var.enable_runlayer_deploy ? "ECS" : ""
    # Conditionally set PUBLIC_RUNLAYER_SKILLS based on enable_runlayer_skills variable
    PUBLIC_RUNLAYER_SKILLS = var.enable_runlayer_skills ? "true" : ""
  }
}
