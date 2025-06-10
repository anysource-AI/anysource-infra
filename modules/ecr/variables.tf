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
    condition     = can(regex("^stg|prod|dr|production|eu$", var.environment))
    error_message = "Invalid environment. Must be either 'stg' or 'prod'"
  }
}
