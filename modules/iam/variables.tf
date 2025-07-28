variable "project" {
  type        = string
  description = "The name of the project"
  validation {
    condition     = length(var.project) > 0
    error_message = "Project name cannot be empty"
  }
}

variable "environment" {
  type        = string
  description = "The environment name"
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty"
  }
}
