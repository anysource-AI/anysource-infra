# Validation: Ensure all services have corresponding ECR repository URIs
locals {
  missing_ecr_services = [
    for svc in keys(var.services_configurations) : svc
    if !contains(keys(var.ecr_repositories), svc)
  ]

  # This will cause an error if any services are missing ECR URIs
  validate_ecr_completeness = length(local.missing_ecr_services) == 0 ? true : tobool("ERROR: Missing ECR repository URIs for services: ${join(", ", local.missing_ecr_services)}. All services must have explicit ECR URIs defined in ecr_repositories variable.")
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

  # Environment variables (non-sensitive)
  env_vars = merge({
    ENVIRONMENT     = var.environment
    PROJECT_NAME    = var.project
    API_V1_STR      = "/api/v1"
    POSTGRES_SERVER = module.rds[var.database_name].cluster_endpoint
    POSTGRES_PORT   = "5432"
    POSTGRES_DB     = var.database_name
    POSTGRES_USER   = var.database_username
    REDIS_URL       = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0"
    }, var.domain_name == "" ? {
    # When no domain is provided, set frontend host and CORS origins to ALB URL as environment variables
    APP_URL              = "http://${module.private_alb.alb_dns_name}"
    BACKEND_CORS_ORIGINS = "http://${module.private_alb.alb_dns_name}"
  } : {})

  # Secrets from AWS Secrets Manager (sensitive data)
  secret_vars = merge({
    POSTGRES_PASSWORD        = "${aws_secretsmanager_secret.app_secrets.arn}:PLATFORM_DB_PASSWORD::"
    SECRET_KEY               = "${aws_secretsmanager_secret.app_secrets.arn}:SECRET_KEY::"
    MASTER_SALT              = "${aws_secretsmanager_secret.app_secrets.arn}:MASTER_SALT::"
    FIRST_SUPERUSER          = "${aws_secretsmanager_secret.app_secrets.arn}:FIRST_SUPERUSER::"
    FIRST_SUPERUSER_PASSWORD = "${aws_secretsmanager_secret.app_secrets.arn}:FIRST_SUPERUSER_PASSWORD::"
    }, var.domain_name != "" ? {
    # When domain is provided, get frontend host and CORS origins from secrets manager
    APP_URL              = "${aws_secretsmanager_secret.app_secrets.arn}:APP_URL::"
    BACKEND_CORS_ORIGINS = "${aws_secretsmanager_secret.app_secrets.arn}:BACKEND_CORS_ORIGINS::"
  } : {})

  depends_on = [module.iam, module.vpc, module.sg_private_alb, module.private_alb, aws_secretsmanager_secret_version.app_secrets]
}
