variable "name" {
  type        = string
  description = "The name of the API Gateway"
  validation {
    condition     = length(var.name) > 0
    error_message = "Name must not be empty"
  }
}

variable "project" {
  type        = string
  description = "The name of the application"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.project))
    error_message = "Invalid project name. Only alphanumeric characters, underscores, and hyphens are allowed."
  }
}

variable "environment" {
  type        = string
  description = "The environment for the API Gateway"
  validation {
    condition     = can(regex("^stg|prod|dr|production|eu$", var.environment))
    error_message = "Invalid environment. Must be either 'stg', 'prod', 'dr', 'production', or 'eu'"
  }
}

variable "route_selection_expression" {
  type        = string
  description = "Route selection expression for the websocket API"
  default     = "$request.body.action"
}

variable "integration_type" {
  type        = string
  description = "Type of integration"
  default     = "HTTP_PROXY"
  validation {
    condition     = contains(["HTTP_PROXY", "AWS_PROXY", "MOCK"], var.integration_type)
    error_message = "Integration type must be one of: HTTP_PROXY, AWS_PROXY, MOCK"
  }
}

variable "integration_method" {
  type        = string
  description = "HTTP method for the integration"
  default     = "POST"
  validation {
    condition     = contains(["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH"], var.integration_method)
    error_message = "Integration method must be a valid HTTP method"
  }
}

variable "target_url" {
  type        = string
  description = "Target URL for the integration"
  validation {
    condition     = length(var.target_url) > 0
    error_message = "Target URL must not be empty"
  }
}


variable "routes" {
  type = map(object({
    route_key                 = string
    enabled                   = optional(bool, true)
    path                      = string
    proxy_integration         = optional(bool, false)
    content_handling_strategy = optional(string)
    integration_type          = optional(string, "HTTP")
    integration_response      = optional(bool, false)
    route_response            = optional(bool, false)
    is_request_templates      = optional(bool, false)
    request_templates         = optional(map(string))
  }))
  description = "Map of routes to create"
  default = {
    connect = {
      route_key = "$connect"
      path      = "connect"
    }
    disconnect = {
      route_key = "$disconnect"
      path      = "disconnect"

    }
    default = {
      route_key = "$default"
      path      = "event"
    }
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for VPC Link"
  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group ID must be provided"
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for VPC Link"
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided"
  }
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}
