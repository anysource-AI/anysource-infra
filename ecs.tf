module "ecs" {
  source                      = "./modules/ecs"
  project                     = var.project
  environment                 = var.environment
  region                      = var.region
  vpc_id                      = module.vpc.vpc_id
  vpc_cidr                    = var.vpc_cidr
  services_configurations     = var.services_configurations
  services_names              = keys(var.services_configurations)
  account                     = var.account // for ECR
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  private_subnets             = module.vpc.private_subnets
  public_subnets              = module.vpc.public_subnets
  public_alb_security_group   = module.sg_private_alb
  public_alb_target_groups    = module.private_alb.target_groups

  # Environment variables (non-sensitive)
  env_vars = {
    ENVIRONMENT     = var.environment
    PROJECT_NAME    = var.project
    API_V1_STR      = "/api/v1"
    POSTGRES_SERVER = module.rds[var.database_name].cluster_endpoint
    POSTGRES_PORT   = "5432"
    POSTGRES_DB     = var.database_name
    REDIS_URL       = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0"
  }

  # Secrets from AWS Secrets Manager (sensitive data)
  secret_vars = {
    POSTGRES_USER            = "${aws_secretsmanager_secret.app_secrets.arn}:PLATFORM_DB_USERNAME::"
    POSTGRES_PASSWORD        = "${aws_secretsmanager_secret.app_secrets.arn}:PLATFORM_DB_PASSWORD::"
    SECRET_KEY               = "${aws_secretsmanager_secret.app_secrets.arn}:SECRET_KEY::"
    FIRST_SUPERUSER          = "${aws_secretsmanager_secret.app_secrets.arn}:FIRST_SUPERUSER::"
    FIRST_SUPERUSER_PASSWORD = "${aws_secretsmanager_secret.app_secrets.arn}:FIRST_SUPERUSER_PASSWORD::"
    FRONTEND_HOST            = "${aws_secretsmanager_secret.app_secrets.arn}:FRONTEND_HOST::"
    BACKEND_CORS_ORIGINS     = "${aws_secretsmanager_secret.app_secrets.arn}:BACKEND_CORS_ORIGINS::"
  }

  depends_on = [module.ecr, module.iam, module.vpc, module.sg_private_alb, module.private_alb, module.rds, aws_elasticache_replication_group.redis]
}

module "ecr" {
  source           = "./modules/ecr"
  project          = var.project
  environment      = var.environment
  ecr_repositories = keys(var.services_configurations)
}

# Reference the secret version
data "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
}
