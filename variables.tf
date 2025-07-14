########################################################################################################################
# Application - Core Required Variables
variable "region" {
  type        = string
  description = "AWS region"
}

variable "profile" {
  type        = string
  description = "AWS profile"
  default     = "default"
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "anysource"
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development"
  }
}

variable "domain_name" {
  type        = string
  description = "Domain name for the application (optional - if not provided, ALB DNS name will be used)"
  default     = ""
}

variable "first_superuser" {
  type        = string
  description = "Email address for the first superuser account (typically your company admin email)"
}

variable "account" {
  type = string
}

# ECR Configuration
variable "ecr_repositories" {
  type        = map(string)
  description = "Map of service names to their ECR repository URIs"
  default     = {}

  validation {
    condition = alltrue([
      for service_name, uri in var.ecr_repositories :
      can(regex("^(public\\.ecr\\.aws/[^/]+/[^:]+:[^:]+|[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+)$", uri))
    ])
    error_message = "ECR repository URIs must be either public ECR (public.ecr.aws/namespace/repo:tag) or private ECR (account.dkr.ecr.region.amazonaws.com/repo:tag) format"
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
  description = "Private subnets"
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# Database Configuration - Simplified
variable "database_name" {
  description = "Database name"
  type        = string
  default     = "anysource"
}

variable "database_config" {
  description = "Database configuration (all optional)"
  type = object({
    engine_version      = optional(string, "16.6")
    min_capacity        = optional(number, 2)
    max_capacity        = optional(number, 16)
    publicly_accessible = optional(bool, false)
    backup_retention    = optional(number, 7)
    subnet_type         = optional(string, "private") # "public" or "private"
  })
  default = {}
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



variable "create_route53_records" {
  description = "Whether to create Route53 DNS records for the domain"
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID (required if create_route53_records is true)"
  type        = string
  default     = ""
}

# Application Services Configuration with Smart Defaults
variable "services_configurations" {
  type = map(object({
    path_pattern                      = list(string)
    health_check_path                 = string
    protocol                          = optional(string, "HTTP")
    port                              = optional(number, 80)
    cpu                               = optional(number) # Will use service-specific defaults if not provided
    memory                            = optional(number) # Will use service-specific defaults if not provided
    host_port                         = optional(number, 8000)
    container_port                    = optional(number, 8000)
    desired_count                     = optional(number, 2) # Production-ready default
    max_capacity                      = optional(number, 2) # Allow scaling
    min_capacity                      = optional(number, 2)
    cpu_auto_scalling_target_value    = optional(number, 70)
    memory_auto_scalling_target_value = optional(number, 80)
    priority                          = optional(number) # Priority for ALB listener rules - lower numbers have higher precedence (1 is highest priority)
    env_vars                          = optional(map(string), {})
    secret_vars                       = optional(map(string), {})
  }))
  default = {
    "backend" = {
      name              = "backend"
      path_pattern      = ["/api/*"]
      health_check_path = "/api/v1/utils/health-check/"
      container_port    = 8000
      host_port         = 8000
      port              = 8000
      priority          = 1
      cpu               = 1024
      memory            = 2048
    }
    "frontend" = {
      name              = "frontend"
      path_pattern      = ["/*"]
      health_check_path = "/"
      container_port    = 80
      host_port         = 80
      priority          = 2
      cpu               = 512
      memory            = 1024
    }
  }
}

# HuggingFace Configuration
variable "hf_token" {
  type        = string
  description = "HuggingFace token for downloading models (used by prompt protection)"
  default     = "" # Must be provided via tfvars or environment variable
  sensitive   = true
}

# Optional Global Environment Variables
variable "env_vars" {
  type        = map(string)
  description = "Global environment variables for all services"
  default     = {}
}

variable "secret_vars" {
  type        = map(string)
  description = "Global secret variables for all services"
  default     = {}
}

# S3 Configuration (Optional)
variable "buckets_conf" {
  type        = map(object({ acl = string }))
  description = "S3 bucket configurations"
  default     = {}
}

variable "buckets_conf_new" {
  type        = map(object({ acl = string }))
  description = "Additional S3 bucket configurations"
  default     = {}
}

# Monitoring and Alerting Configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = false
}

variable "enable_chatbot_alerts" {
  description = "Enable monitoring alerts via AWS Chatbot (much simpler than SNS for enterprise)"
  type        = bool
  default     = false
}

variable "slack_channel_id" {
  description = "Slack channel ID for alerts (e.g., C1234567890)"
  type        = string
  default     = ""
}

variable "slack_team_id" {
  description = "Slack team/workspace ID (e.g., T1234567890)"
  type        = string
  default     = ""
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

# Legacy variables removed - use database_config instead

variable "suffix_secret_hash" {
  type        = string
  description = "Suffix for secret names to ensure uniqueness"
  default     = ""
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection for RDS clusters"
  default     = true
}
