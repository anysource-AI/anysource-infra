# Shared locals for consistent logic across modules
locals {
  # Always set enable_https based on domain_name (HTTPS enabled only when domain is provided)
  enable_https = var.domain_name != ""
} 
