variable "name" {
  type        = string
  description = "The name of the ALB"
  validation {
    condition     = length(var.name) > 0
    error_message = "Name must not be empty"
  }
}

variable "project" {
  type        = string
  description = "The name of the application"
}

variable "environment" {
  type        = string
  description = "The environment of the ALB"
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment must not be empty"
  }
}

variable "internal" {
  type        = bool
  default     = false
  description = "Whether the ALB is internal or external"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
  validation {
    condition     = length(var.vpc_id) > 0
    error_message = "VPC ID must not be empty"
  }
}

variable "load_balancer_type" {
  type        = string
  description = "The type of load balancer"
  validation {
    condition     = var.load_balancer_type == "application" || var.load_balancer_type == "network"
    error_message = "Load balancer type must be either 'application' or 'network'"
  }
  default = "application"
}

variable "subnets" {
  type = list(string)
}

variable "security_groups" {
  type = list(string)
}

variable "target_groups" {
  type = map(object({
    path_pattern      = list(string)
    health_check_path = string
    protocol          = optional(string, "HTTP") // Optional protocol
    port              = optional(number, 3000)   // Optional port
    priority          = number                   // Priority for ALB listener rules

  }))

}
variable "certificate_arn" {
  type    = string
  default = ""
}
