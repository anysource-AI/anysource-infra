# Generate a random suffix for secret name uniqueness
resource "random_string" "secret_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create the secrets manager secret with proper environment naming
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${var.project}-${var.environment == "production" ? "prod" : var.environment}-${random_string.secret_suffix.result}"
  description = "Application secrets for ${var.project} ${var.environment} environment"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Generate random passwords for better security
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!()_-="
  min_lower        = 8
  min_upper        = 8
  min_numeric      = 8
  min_special      = 8
}

resource "random_password" "secret_key" {
  length  = 32
  special = false
}

resource "random_password" "master_salt" {
  length  = 32
  special = false
}

# Application configuration secret version with dynamically generated secrets
resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode(merge({
    PLATFORM_DB_PASSWORD = random_password.db_password.result
    SECRET_KEY           = random_password.secret_key.result
    MASTER_SALT          = random_password.master_salt.result
    HF_TOKEN             = var.hf_token
    SENTRY_DSN           = var.sentry_dsn
    }, var.domain_name != "" ? {
    # When domain is provided, use HTTPS with domain
    APP_URL              = "https://${var.domain_name}"
    BACKEND_CORS_ORIGINS = "https://${var.domain_name}"
  } : {}))
}
