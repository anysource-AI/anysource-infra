########################################################################################################################
# Secrets Management
########################################################################################################################

resource "random_id" "secret_suffix" {
  byte_length = 4
}

module "app_secrets" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name        = "${var.project}-${var.environment}-app-secrets-${random_id.secret_suffix.hex}"
  description = "Application secrets for ${var.project} ${var.environment}"

  recovery_window_in_days = 7

  secret_string = jsonencode({
    PLATFORM_DB_PASSWORD = var.database_password
    SECRET_KEY           = var.secret_key
    MASTER_SALT          = var.master_salt
    SENTRY_DSN           = var.sentry_dsn
    AUTH_API_KEY         = var.auth_api_key
  })

  tags = local.common_tags
}
