variable "project" {
  type        = string
  description = "The name of the application"
}

variable "ecr_repositories" {
  type        = list(string)
  description = "A list of ECR repository names"
}

variable "environment" {
  type        = string
  description = "The environment for the application"
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty"
  }
}
