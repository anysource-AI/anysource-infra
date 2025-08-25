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

variable "account_id" {
  type        = string
  description = "The AWS account ID"
  validation {
    condition     = length(var.account_id) > 0
    error_message = "Account ID cannot be empty"
  }
}

variable "region" {
  type        = string
  description = "The AWS region"
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty"
  }
}
