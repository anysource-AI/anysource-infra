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

variable "app_version" {
  type        = string
  description = "Application version used to build default ECR image tags (mutually exclusive with ecr_repositories)."
  default     = null

  validation {
    condition     = var.app_version == null || length(trimspace(var.app_version)) > 0
    error_message = "app_version cannot be an empty string."
  }

  validation {
    condition     = !(var.app_version != null && var.ecr_repositories != null)
    error_message = "Provide either app_version or ecr_repositories, not both."
  }
}

variable "ecr_repositories" {
  type        = map(string)
  description = "Map of service names to their ECR repository URIs (backend, worker, frontend required). Overrides the module defaults."
  default     = null

  validation {
    condition     = var.ecr_repositories == null || length(var.ecr_repositories) > 0
    error_message = "ecr_repositories cannot be an empty map. Provide image URIs for all services or omit to use defaults."
  }

  validation {
    condition = var.ecr_repositories == null ? true : alltrue([
      for service_name, uri in var.ecr_repositories :
      can(regex("^(public\\.ecr\\.aws/[^/]+/[^:]+:[^:]+|[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+)$", uri))
    ])
    error_message = "ECR repository URIs must be either public ECR (public.ecr.aws/namespace/repo:tag) or private ECR (account.dkr.ecr.region.amazonaws.com/repo:tag) format"
  }

  validation {
    condition = var.ecr_repositories == null ? true : alltrue([
      for _, uri in var.ecr_repositories :
      can(regex(":[^/:@]+$|@sha256:[0-9a-fA-F]{64}$", uri))
    ])
    error_message = "Each ECR repository URI must include an explicit image tag or digest (no implicit latest)."
  }

  validation {
    condition = var.ecr_repositories == null ? true : alltrue([
      for required in ["backend", "frontend", "worker"] :
      contains(keys(var.ecr_repositories), required)
    ])
    error_message = "ecr_repositories must include backend, frontend, and worker entries."
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

# Dual ALB Configuration for Split-Horizon DNS
variable "enable_dual_alb" {
  description = "Enable dual ALB setup (public + internal) for split-horizon DNS. When enabled, creates both a public ALB for internet traffic and an internal ALB for private network traffic."
  type        = bool
  default     = false
}

variable "private_hosted_zone_id" {
  description = "Existing Route53 private hosted zone ID to use for internal DNS. If not provided and enable_dual_alb is true, a new private hosted zone will be created."
  type        = string
  default     = ""
}

variable "private_hosted_zone_vpc_id" {
  description = "VPC ID to associate with the private hosted zone. If empty, uses the service VPC (local.vpc_id). Only applies when enable_dual_alb is true and private_hosted_zone_id is not provided."
  type        = string
  default     = ""
}

variable "private_hosted_zone_additional_vpc_ids" {
  description = "Additional VPC IDs to associate with the private hosted zone (e.g., for VPC peering scenarios). Same-account associations only; cross-account requires AWS RAM."
  type        = list(string)
  default     = []
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
  description = "Enable SCIM / Directory Sync scheduled task (event-based incremental sync)"
  default     = true
}

variable "directory_sync_interval_minutes" {
  type        = number
  description = "Interval in minutes between directory sync runs (event-based sync)"
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

# ========================================
# RUNLAYER TOOL GUARD CONFIGURATION - OPTIONAL
# ========================================
variable "enable_runlayer_tool_guard" {
  type        = bool
  description = "Enable Runlayer ToolGuard Flask server deployment"
  default     = false
}

variable "runlayer_tool_guard_image_uri" {
  type        = string
  description = "Docker image URI for the Runlayer ToolGuard Flask server"
  default     = "public.ecr.aws/anysource/anysource-models:runlayer-multimodel-guard-v202512081738"
}

variable "runlayer_tool_guard_desired_count" {
  type        = number
  description = "Desired number of Runlayer ToolGuard service instances"
  default     = 1

  validation {
    condition     = var.runlayer_tool_guard_desired_count >= 1 && var.runlayer_tool_guard_desired_count <= 5
    error_message = "Runlayer ToolGuard desired count must be between 1 and 5"
  }
}

variable "runlayer_tool_guard_timeout" {
  type        = number
  description = "Timeout in seconds for Runlayer ToolGuard requests"
  default     = 5

  validation {
    condition     = var.runlayer_tool_guard_timeout >= 5 && var.runlayer_tool_guard_timeout <= 300
    error_message = "Runlayer ToolGuard timeout must be between 5 and 300 seconds"
  }
}

variable "runlayer_tool_guard_log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days for Runlayer ToolGuard. Longer retention recommended for security auditing and compliance."
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.runlayer_tool_guard_log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period (e.g., 7, 30, 60, 90, 180, 365 days)"
  }
}

variable "enable_runlayer_tool_guard_alarms" {
  type        = bool
  description = "Enable CloudWatch alarms for Runlayer ToolGuard service health and performance monitoring"
  default     = true
}

# Deployment Feature Flag
variable "enable_runlayer_deploy" {
  type        = bool
  description = "Enable RunLayer deployment features (requires ECS infrastructure). Set to true to allow deploying custom MCP servers."
  default     = false
}

# Skills Feature Flag
variable "enable_runlayer_skills" {
  type        = bool
  description = "Enable RunLayer Skills feature. Set to true to show Skills navigation item in the UI."
  default     = true
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

variable "backend_cors_origins" {
  type        = list(string)
  description = "Optional list of backend CORS origins; leave empty to let the backend default to APP_URL."
  default     = []
  validation {
    condition     = length(var.backend_cors_origins) == 0 || alltrue([for origin in var.backend_cors_origins : can(regex("^https?://", origin))])
    error_message = "backend_cors_origins entries must start with http:// or https://"
  }
}

# Client IP Header Configuration for Rate Limiting
variable "client_ip_header" {
  type        = string
  description = "HTTP header to extract client IP from for rate limiting. When set, uses this header's value directly. When empty (default), uses x-forwarded-for with comma-split logic for proxy chains. For ECS with ALB, leave empty as ALB appends client IP to x-forwarded-for."
  default     = ""
}

# OAuth Client Registration Rate Limit
variable "oauth_client_registration_rate_limit_per_hour" {
  type        = number
  description = "Maximum number of OAuth client registration requests per hour per IP address. Used to prevent abuse of the dynamic client registration endpoint."
  default     = 1000
}

# VPC Peering Configuration
variable "vpc_peering_connections" {
  description = "Map of VPC peering connections to accept and configure routes for. Only works when creating a new VPC (not with existing_vpc_id). Optional - defaults to no peering. SECURITY: peer_owner_id is now REQUIRED for all connections to prevent accepting connections from unknown sources."
  type = map(object({
    peering_connection_id = string               # VPC peering connection ID to accept
    peer_vpc_cidr         = string               # CIDR of the peer VPC for routing
    peer_owner_id         = string               # Peer account ID (REQUIRED for security validation)
    peer_region           = optional(string, "") # Peer region (cross-region, optional)
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, peer in var.vpc_peering_connections :
      peer.peer_owner_id != null && peer.peer_owner_id != ""
    ])
    error_message = "All VPC peering connections must have peer_owner_id specified. This is required for security validation to ensure you only accept connections from known and trusted AWS accounts."
  }

  validation {
    condition = alltrue([
      for key, peer in var.vpc_peering_connections :
      !cidrcontains(var.vpc_cidr, peer.peer_vpc_cidr) && !cidrcontains(peer.peer_vpc_cidr, var.vpc_cidr)
    ])
    error_message = "VPC peering CIDR blocks must not overlap with the current VPC CIDR. Overlapping CIDR blocks cause routing conflicts and are not allowed. Please ensure peer_vpc_cidr does not overlap with vpc_cidr."
  }
}

# VPC Endpoints Configuration
variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services to reduce NAT Gateway costs. Creates endpoints for S3 (gateway, FREE), ECR API, ECR Docker, and CloudWatch Logs (3 interface endpoints, ~$21.60/month). Only applies when creating a new VPC (not with existing_vpc_id)."
  type        = bool
  default     = true
}
