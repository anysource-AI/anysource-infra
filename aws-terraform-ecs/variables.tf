########################################################################################################################
# Application - Core Required Variables
variable "region" {
  type        = string
  description = "AWS region"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the application (required)"
  validation {
    condition     = length(var.domain_name) > 0
    error_message = "Domain name is required for all deployments."
  }
}

variable "account" {
  type        = string
  description = "AWS account ID"
}

# Auth Configuration
variable "auth_client_id" {
  type        = string
  description = "Auth client ID for authentication. This will be provided by the Runlayer team."
  validation {
    condition     = length(var.auth_client_id) > 0
    error_message = "auth_client_id must not be empty. Ask Runlayer support for your auth_client_id."
  }
}
variable "auth_api_key" {
  type        = string
  description = "Auth API key for authentication. This will be provided by the Runlayer team."
  sensitive   = true
  validation {
    condition     = length(var.auth_api_key) > 0
    error_message = "auth_api_key must not be empty. Ask Runlayer support for your auth_api_key."
  }
}

variable "ecr_repositories" {
  type        = map(string)
  description = "Map of service names to their ECR repository URIs (backend, worker, frontend required)"
  default     = {}

  validation {
    condition = alltrue([
      for service_name, uri in var.ecr_repositories :
      can(regex("^(public\\.ecr\\.aws/[^/]+/[^:]+:[^:]+|[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+)$", uri))
    ])
    error_message = "ECR repository URIs must be either public ECR (public.ecr.aws/namespace/repo:tag) or private ECR (account.dkr.ecr.region.amazonaws.com/repo:tag) format"
  }
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "anysource"
  validation {
    condition     = length(var.project) <= 10 && length(var.project) > 0
    error_message = "Project name must be between 1 and 10 characters."
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project))
    error_message = "Project name must contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development"
  }
}

# VPC Configuration with Smart Defaults
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

variable "region_az" {
  type        = list(string)
  description = "Availability zones"
  default     = [] # Will be auto-populated based on region if empty
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets (CIDR blocks for VPC creation)"
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets (CIDR blocks for VPC creation)"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# Optional External VPC Configuration
variable "existing_vpc_id" {
  type        = string
  description = "ID of an existing VPC to use instead of creating a new one. If provided, existing_private_subnet_ids and existing_public_subnet_ids must also be provided."
  default     = null
}

variable "existing_private_subnet_ids" {
  type        = list(string)
  description = "List of existing private subnet IDs to use. Required if existing_vpc_id is provided."
  default     = null
}

variable "existing_public_subnet_ids" {
  type        = list(string)
  description = "List of existing public subnet IDs to use. Required if existing_vpc_id is provided."
  default     = null
}

# Database Configuration
variable "database_name" {
  description = "Database name"
  type        = string
  default     = "anysource"
}

variable "database_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "database_config" {
  description = "Database configuration (all optional)"
  type = object({
    engine_version             = optional(string, "16.8")
    min_capacity               = optional(number, 2)
    max_capacity               = optional(number, 16)
    publicly_accessible        = optional(bool, false)
    backup_retention           = optional(number, 7)
    subnet_type                = optional(string, "private") # "public" or "private"
    force_ssl                  = optional(bool, false)
    auto_minor_version_upgrade = optional(bool, false)
    skip_final_snapshot        = optional(bool, false)
    delete_automated_backups   = optional(bool, false) # Set to true for dev/sandbox to save costs

    # Database connection pool settings
    pool_size     = optional(number, 50)   # Number of connections to maintain in the pool
    max_overflow  = optional(number, 50)   # Additional connections allowed beyond pool_size
    pool_timeout  = optional(number, 30)   # Seconds to wait for a connection from the pool
    pool_recycle  = optional(number, 3600) # Seconds before recreating a connection (1 hour)
    pool_pre_ping = optional(bool, true)   # Test connections before use to handle disconnections
  })
  default = {}
}

variable "workers" {
  type        = number
  description = "Number of workers for the backend"
  default     = null # Set to null to use the number of CPUs on the node
}

# ALB/Security Configuration
variable "alb_access_type" {
  description = "ALB access type (public allows internet access, private restricts to VPC)"
  type        = string
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.alb_access_type)
    error_message = "ALB access type must be 'public' or 'private'."
  }
}

variable "alb_allowed_cidrs" {
  description = "CIDR blocks allowed to access the ALB (only applies to public ALBs)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# SSL Certificate Configuration
variable "ssl_certificate_arn" {
  description = "Existing SSL certificate ARN (optional - will create new ACM certificate if not provided)"
  type        = string
  default     = ""
}

variable "enable_acm_dns_validation" {
  description = "Automatically create Route53 validation records and validate the generated ACM certificate"
  type        = bool
  default     = false
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name used whenever enable_acm_dns_validation is true"
  type        = string
  default     = ""

  validation {
    condition     = var.enable_acm_dns_validation == false || length(trimspace(var.hosted_zone_name)) > 0
    error_message = "When enable_acm_dns_validation is true, hosted_zone_name must be provided for Route53 zone lookup."
  }
}

# Application Services Configuration with Smart Defaults
variable "services_configurations" {
  type = map(object({
    name                              = string
    path_pattern                      = list(string)
    health_check_path                 = string
    protocol                          = optional(string, "HTTP")
    port                              = optional(number, 80)
    cpu                               = optional(number) # Will use service-specific defaults if not provided
    memory                            = optional(number) # Will use service-specific defaults if not provided
    host_port                         = optional(number, 8000)
    container_port                    = optional(number, 8000)
    desired_count                     = optional(number, 3)  # Production-ready default
    max_capacity                      = optional(number, 20) # Allow scaling
    min_capacity                      = optional(number, 3)
    cpu_auto_scalling_target_value    = optional(number, 70)
    memory_auto_scalling_target_value = optional(number, 80)
    priority                          = number # Priority for ALB listener rules - lower numbers have higher precedence (1 is highest priority)
  }))
  default = {
    "backend" = {
      name              = "backend"
      path_pattern      = ["/api/*", "/docs*", "/redoc*", "/openapi.json", "/.well-known*"]
      health_check_path = "/api/v1/utils/health-check/"
      container_port    = 8000
      host_port         = 8000
      port              = 8000
      priority          = 1
      cpu               = 4096
      memory            = 8192
    }
    "frontend" = {
      name              = "frontend"
      path_pattern      = ["/*"]
      health_check_path = "/"
      container_port    = 80
      host_port         = 80
      port              = 80
      priority          = 2
      cpu               = 1024
      memory            = 2048
    }
  }
}

# Sentry Configuration
# By default, SENTRY_DSN is fetched from WorkOS Vault via vault-integration.tf
# Can be optionally overridden (useful for sandbox/dev environments with different Sentry projects)
variable "sentry_dsn" {
  type        = string
  description = "Sentry DSN override for this environment. If empty, uses value from WorkOS Vault."
  default     = ""
  sensitive   = true
}

# Sentry Relay Configuration
variable "sentry_relay_enabled" {
  type        = bool
  description = "Enable Sentry Relay deployment. If false, disables relay even if credentials are available. Useful for debugging or cost optimization."
  default     = true
}

variable "sentry_relay_upstream" {
  type        = string
  description = "Upstream Sentry endpoint for Relay"
  default     = "https://o4509836808028160.ingest.us.sentry.io"
}

variable "sentry_relay_config" {
  type = object({
    cpu            = optional(number, 1024) # 1 vCPU (multi-core recommended per Sentry guidelines)
    memory         = optional(number, 2048) # 2GB RAM (minimum per Sentry Operating Guidelines)
    desired_count  = optional(number, 2)    # Run 2 for HA
    container_port = optional(number, 3000)
  })
  description = "Sentry Relay ECS task configuration. See: https://docs.sentry.io/product/relay/operating-guidelines/"
  default     = {}
}

# Deployment identification for telemetry
# customer_id defaults to domain_name if not specified
variable "customer_id" {
  type        = string
  description = "Customer identifier for this deployment (defaults to domain name for telemetry tagging)"
  default     = ""
}

# Infrastructure version for release tracking in Sentry
# NOTE: Changing this variable requires ECS task restart for the new value to appear in Sentry tags.
# The infra_version is set as an environment variable at container startup.
# If not provided, it defaults to the app version (image tag) used for deployment.
variable "infra_version" {
  type        = string
  description = "Infrastructure version for tracking deployment changes in Sentry (defaults to app image tag when not provided)"
  default     = ""
}

# Monitoring and Alerting Configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = false
}

variable "alb_5xx_alarm_period" {
  description = "CloudWatch alarm period (seconds) for ALB 5XX errors"
  type        = number
  default     = 300
}

variable "alb_5xx_alarm_threshold" {
  description = "CloudWatch alarm threshold for ALB 5XX errors"
  type        = number
  default     = 1
}

# RDS Monitoring and Alerting Configuration

variable "rds_alarm_config" {
  description = "Map of RDS CloudWatch alarm configs for each metric. Each object must include period, threshold, and unit."
  type = map(object({
    period    = number
    threshold = number
    unit      = string
  }))
  default = {
    FreeableMemory = {
      period    = 300
      threshold = 268435456 # 256MB
      unit      = "Bytes"
    }
    DiskQueueDepth = {
      period    = 300
      threshold = 5
      unit      = "Count"
    }
    WriteIOPS = {
      period    = 300
      threshold = 1000
      unit      = "Count"
    }
    ReadIOPS = {
      period    = 300
      threshold = 1000
      unit      = "Count"
    }
    Storage = {
      period    = 300
      threshold = 107374182400 # 100GB
      unit      = "Bytes"
    }
  }
  validation {
    condition = alltrue([
      for k, v in var.rds_alarm_config : v.period > 0 && v.threshold > 0
    ])
    error_message = "All RDS alarm periods and thresholds must be positive numbers."
  }
}


variable "prestart_container_cpu" {
  type        = number
  description = "CPU units for the prestart container"
  default     = 512
}

variable "prestart_container_memory" {
  type        = number
  description = "Memory (MB) for the prestart container"
  default     = 1024
}

variable "prestart_timeout_seconds" {
  type        = number
  description = "Timeout in seconds for prestart container to complete"
  default     = 300
}

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Grace period in seconds before health checks start"
  default     = 120
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection for RDS clusters"
  default     = true
}

# Redis Configuration
variable "redis_node_type" {
  type        = string
  description = "ElastiCache Redis node type"
  default     = "cache.t3.medium"
}

# Version Configuration
variable "version_url" {
  type        = string
  description = "URL endpoint for version information"
  default     = "https://anysource-version.s3.amazonaws.com/version.json"
}

# OAuth Broker Configuration
variable "oauth_broker_url" {
  type        = string
  description = "OAuth Broker URL for OAuth flow handling"
  default     = ""
}

# SCIM / Directory Sync Configuration
variable "directory_sync_enabled" {
  type        = bool
  description = "Enable SCIM / Directory Sync scheduled task"
  default     = true
}

variable "directory_sync_interval_minutes" {
  type        = number
  description = "Interval in minutes between directory sync runs"
  default     = 10
  validation {
    condition     = var.directory_sync_interval_minutes >= 1 && var.directory_sync_interval_minutes <= 1440
    error_message = "Directory sync interval must be between 1 and 1440 minutes (24 hours)"
  }
}
variable "worker_config" {
  description = "Worker configuration for background job processing"
  type = object({
    cpu           = optional(number, 1024)
    memory        = optional(number, 2048)
    desired_count = optional(number, 1)
    max_capacity  = optional(number, 5)
    min_capacity  = optional(number, 1)
  })
  default = {}
}
variable "enable_ecs_exec" {
  type        = bool
  description = "Enable ECS Exec for interactive shell access to backend containers. Use only for development and testing purposes."
  default     = false
}


# Bedrock Guardrail Configuration
variable "bedrock_prompt_guard_sensitivity" {
  type        = string
  description = "Sensitivity level for Bedrock guardrail prompt attack detection. Valid values: LOW, MEDIUM, HIGH."
  default     = "MEDIUM"
  validation {
    condition     = contains(["LOW", "MEDIUM", "HIGH"], var.bedrock_prompt_guard_sensitivity)
    error_message = "bedrock_prompt_guard_sensitivity must be one of: LOW, MEDIUM, HIGH"
  }
}

# WAF IP Allowlisting Configuration
variable "waf_enable_ip_allowlisting" {
  type        = bool
  description = "Enable WAF IP allowlisting to restrict ALB access to specific IPv4 CIDR blocks"
  default     = false
}

variable "waf_allowlist_ipv4_cidrs" {
  type        = list(string)
  description = "List of IPv4 CIDR blocks to allowlist in the WAF (e.g., ['1.2.3.4/32', '10.0.0.0/8'])"
  default     = []
  validation {
    condition     = !var.waf_enable_ip_allowlisting || length(var.waf_allowlist_ipv4_cidrs) > 0
    error_message = "waf_allowlist_ipv4_cidrs must not be empty when waf_enable_ip_allowlisting is true. Provide at least one IPv4 CIDR block to avoid locking yourself out."
  }
}
