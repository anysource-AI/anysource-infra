# Validation: Ensure all services have corresponding ECR repository URIs
locals {
  missing_ecr_services = [
    for svc in keys(var.services_configurations) : svc
    if !contains(keys(var.ecr_repositories), svc)
  ]

  # This will cause an error if any services are missing ECR URIs
  validate_ecr_completeness = length(local.missing_ecr_services) == 0 ? true : tobool("ERROR: Missing ECR repository URIs for services: ${join(", ", local.missing_ecr_services)}. All services must have explicit ECR URIs defined in ecr_repositories variable.")

  app_url = var.domain_name == "" ? "http://${module.private_alb.alb_dns_name}" : "https://${var.domain_name}"
}

module "ecs" {
  source                            = "./modules/ecs"
  project                           = var.project
  environment                       = var.environment
  region                            = var.region
  vpc_id                            = module.vpc.vpc_id
  vpc_cidr                          = var.vpc_cidr
  services_configurations           = var.services_configurations
  services_names                    = keys(var.services_configurations)
  ecr_repositories                  = var.ecr_repositories
  ecs_task_execution_role_arn       = module.iam.ecs_task_execution_role_arn
  private_subnets                   = module.vpc.private_subnets
  public_subnets                    = module.vpc.public_subnets
  public_alb_security_group         = module.sg_private_alb
  public_alb_target_groups          = module.private_alb.target_groups
  prestart_container_cpu            = var.prestart_container_cpu
  prestart_container_memory         = var.prestart_container_memory
  prestart_timeout_seconds          = var.prestart_timeout_seconds
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Backend-specific environment variables (non-sensitive)
  backend_env_vars = {
    ENVIRONMENT          = var.environment
    API_V1_STR           = "/api/v1"
    POSTGRES_SERVER      = module.rds[var.database_name].cluster_endpoint
    POSTGRES_PORT        = "5432"
    POSTGRES_DB          = var.database_name
    POSTGRES_USER        = var.database_username
    POSTGRES_SSL_MODE    = var.database_config.force_ssl == 1 ? "require" : "prefer"
    REDIS_URL            = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0"
    AUTH_DOMAIN          = var.auth_domain
    APP_URL              = local.app_url
    BACKEND_CORS_ORIGINS = local.app_url
    WORKERS              = var.workers
    # Database connection pool settings
    DB_POOL_SIZE         = var.database_config.pool_size
    DB_MAX_OVERFLOW      = var.database_config.max_overflow
    DB_POOL_TIMEOUT      = var.database_config.pool_timeout
    DB_POOL_RECYCLE      = var.database_config.pool_recycle
    DB_POOL_PRE_PING     = var.database_config.pool_pre_ping
  }

  # Backend-specific secrets from AWS Secrets Manager
  backend_secret_vars = {
    POSTGRES_PASSWORD = "${aws_secretsmanager_secret.app_secrets.arn}:PLATFORM_DB_PASSWORD::"
    SECRET_KEY        = "${aws_secretsmanager_secret.app_secrets.arn}:SECRET_KEY::"
    MASTER_SALT       = "${aws_secretsmanager_secret.app_secrets.arn}:MASTER_SALT::"
    SENTRY_DSN        = "${aws_secretsmanager_secret.app_secrets.arn}:SENTRY_DSN::"
    HF_TOKEN          = "${aws_secretsmanager_secret.app_secrets.arn}:HF_TOKEN::"
  }

  # Frontend-specific environment variables (non-sensitive)
  frontend_env_vars = {
    PUBLIC_AUTH_DOMAIN    = var.auth_domain
    PUBLIC_AUTH_CLIENT_ID = var.auth_client_id
    PUBLIC_APP_URL        = local.app_url
    PUBLIC_BACKEND_URL    = local.app_url
  }

  depends_on = [module.iam, module.vpc, module.sg_private_alb, module.private_alb, aws_secretsmanager_secret_version.app_secrets]
}
