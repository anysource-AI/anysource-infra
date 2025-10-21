# Shared locals for consistent logic across modules
locals {
  app_url = "https://${var.domain_name}"

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
    APP_URL              = local.app_url
    AUTH_CLIENT_ID       = var.auth_client_id
    BACKEND_CORS_ORIGINS = local.app_url
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
  }

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
    PUBLIC_AUTH_CLIENT_ID  = var.auth_client_id
    PUBLIC_APP_URL         = local.app_url
    PUBLIC_BACKEND_URL     = local.app_url
    PUBLIC_BACKEND_VERSION = local.backend_image_tag
    PUBLIC_WEBAPP_VERSION  = local.frontend_image_tag
    PUBLIC_VERSION_URL     = var.version_url
  }
}
