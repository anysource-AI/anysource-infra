variable "project" {
  type = string
}


variable "ecr_repositories" {
  type        = map(string)
  description = "Map of service names to their ECR repository URIs. Must contain entries for all services to prevent fallback to Docker Hub."

  validation {
    condition     = length(var.ecr_repositories) > 0
    error_message = "ecr_repositories cannot be empty. Define ECR URIs for all services to prevent Docker Hub fallback and rate limiting."
  }
}

variable "region" {
  type = string
}
variable "backend_env_vars" {
  type        = map(string)
  default     = {}
  description = "Environment variables specific to the backend service"
}

variable "frontend_env_vars" {
  type        = map(string)
  default     = {}
  description = "Environment variables specific to the frontend service"
}

variable "backend_secret_vars" {
  type        = map(string)
  default     = {}
  description = "Secret variables specific to the backend service"
  sensitive   = true
}
variable "environment" {
  type = string
}
variable "services_names" {
  type = list(string)
}
variable "ecs_task_execution_role_arn" {
  type = string
}
variable "ecs_task_role_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}


variable "public_alb_security_group" {
  type = any
}


variable "public_alb_target_groups" {
  type = map(object({
    arn = string
  }))
}

variable "internal_alb_target_groups" {
  type = map(object({
    arn = string
  }))
  default     = null
  description = "Internal ALB target groups for dual ALB setup. When provided, ECS services will register with both public and internal ALBs."
}

variable "services_configurations" {
}

variable "prestart_container_cpu" {
  type        = number
  description = "CPU units for the prestart container"
}

variable "prestart_container_memory" {
  type        = number
  description = "Memory (MB) for the prestart container"
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

variable "enable_ecs_exec" {
  type        = bool
  description = "Enable ECS Exec for interactive shell access to containers"
  default     = false
}

variable "enable_dual_alb" {
  type        = bool
  description = "Whether dual ALB setup is enabled"
  default     = false
}

variable "vpc_peering_connections" {
  description = "VPC peering connections for security group rules and routing"
  type = map(object({
    peering_connection_id = string               # VPC peering connection ID to accept
    peer_vpc_cidr         = string               # CIDR of the peer VPC for routing
    peer_owner_id         = string               # Peer account ID (REQUIRED for security validation)
    peer_region           = optional(string, "") # Peer region (cross-region, optional)
  }))
  default = {}
}
