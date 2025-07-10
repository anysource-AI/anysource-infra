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
variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_vars" {
  type    = map(string)
  default = {}
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


variable "services_configurations" {
}
