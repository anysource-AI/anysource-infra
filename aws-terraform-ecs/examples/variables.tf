# ========================================
# Module Version Configuration
# ========================================

variable "release_version" {
  type        = string
  description = "Version/ref of the runlayer-infra module to use (e.g., v1.0.0, v1.1.0)"
  default     = "v1.0.0"
}

# ========================================
# Authentication Configuration
# ========================================

variable "auth_client_id" {
  type        = string
  description = "Auth client ID for authentication (provided by Runlayer support)"
}

variable "auth_api_key" {
  type        = string
  description = "Auth API key for authentication (provided by Runlayer support)"
  sensitive   = true
}

# ========================================
# Container Images
# ========================================

variable "ecr_repositories" {
  type        = map(string)
  description = "Map of service names to their ECR repository URIs (backend, worker, frontend required)"
  default = {
    backend  = "public.ecr.aws/anysource/anysource-api:v1.0.0"
    frontend = "public.ecr.aws/anysource/anysource-web:v1.0.0"
    worker   = "public.ecr.aws/anysource/anysource-worker:v1.0.0"
  }
}

# ========================================
# Monitoring Configuration
# ========================================

variable "sentry_dsn" {
  type        = string
  description = "Sentry DSN for error tracking and monitoring"
  default     = ""
}

# ========================================
# Network Configuration Variables (for existing VPC)
# ========================================

# VPC Configuration (for existing VPC)
variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC (required when using existing VPC - MODE 2)"
  default     = ""
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of existing private subnet IDs (required when using existing VPC - MODE 2)"
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of existing public subnet IDs (required when using existing VPC - MODE 2)"
  default     = []
}

# ========================================
# WAF IP Allowlisting Configuration
# ========================================

variable "waf_enable_ip_allowlisting" {
  type        = bool
  description = "Enable WAF IP allowlisting to restrict ALB access to specific IPv4 CIDR blocks"
  default     = false
}

variable "waf_allowlist_ipv4_cidrs" {
  type        = list(string)
  description = "List of IPv4 CIDR blocks to allowlist in the WAF (e.g., ['1.2.3.4/32', '10.0.0.0/8'])"
  default     = []
}
