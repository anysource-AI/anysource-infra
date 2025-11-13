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
  description = "The environment for the application"
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty"
  }
}

variable "name" {
  type        = string
  description = "The name of the variable"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.name))
    error_message = "Invalid variable name. Only alphanumeric characters, underscores, and hyphens are allowed."
  }
}

variable "cloudwatch_metrics" {
  type        = bool
  description = "Enable CloudWatch metrics"
  default     = true
}

variable "sampled_requests" {
  type        = bool
  description = "Enable sampled requests enabled"
  default     = true
}

variable "metric_name" {
  type        = string
  description = "metric_name"
}
variable "resources_arn" {
  type        = list(string)
  description = "resources_arn"
}

variable "enable_ip_allowlisting" {
  type        = bool
  description = "Enable IP allowlisting for the WAF"
  default     = false
}

variable "allowlist_ipv4_cidrs" {
  type        = list(string)
  description = "List of IPv4 CIDR blocks to allowlist"
  default     = []
}
