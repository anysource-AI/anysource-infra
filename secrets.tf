# Create the secrets manager secret with proper environment naming
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${var.project}-${var.environment == "production" ? "prod" : var.environment}"
  description = "Application secrets for ${var.project} ${var.environment} environment"

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Generate random passwords for better security
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "random_password" "superuser_password" {
  length  = 16
  special = true
}

resource "random_password" "secret_key" {
  length  = 32
  special = false
}

# Application configuration secret version with dynamically generated secrets
resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    PLATFORM_DB_USERNAME     = "postgres"
    PLATFORM_DB_PASSWORD     = random_password.db_password.result
    SECRET_KEY               = random_password.secret_key.result
    FIRST_SUPERUSER          = var.first_superuser
    FIRST_SUPERUSER_PASSWORD = random_password.superuser_password.result
    FRONTEND_HOST            = "https://${var.domain_name}"
    BACKEND_CORS_ORIGINS     = "https://${var.domain_name}"
  })
}
