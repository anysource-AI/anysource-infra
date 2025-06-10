variable "environment" {
  type        = string
  description = "The environment name"
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty"
  }
}

variable "project" {
  type        = string
  description = "The project name"
  validation {
    condition     = length(var.project) > 0
    error_message = "project name cannot be empty"
  }
}
