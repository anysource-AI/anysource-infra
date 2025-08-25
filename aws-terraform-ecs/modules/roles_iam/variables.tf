variable "role_names" {
  type        = list(string)
  description = "The role_names of the roles"
}

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

variable "suffix_secret_hash" {
  type        = string
  description = "The suffix_secret_hash of the secret name"
  validation {
    condition     = length(var.suffix_secret_hash) > 0
    error_message = "the suffix of the secret name is missing"
  }
}
