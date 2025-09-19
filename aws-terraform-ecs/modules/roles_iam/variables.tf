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

variable "account" {
  type        = string
  description = "The account id"
  validation {
    condition     = length(var.account) > 0
    error_message = "account id cannot be empty"
  }
}

variable "region" {
  type        = string
  description = "The region"
  validation {
    condition     = length(var.region) > 0
    error_message = "region cannot be empty"
  }
}
