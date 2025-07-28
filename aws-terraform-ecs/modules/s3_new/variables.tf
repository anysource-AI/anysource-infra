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

variable "name" {
  type        = string
  description = "The name name"
}

variable "acl" {
  type        = string
  description = "acl"
  validation {
    condition     = var.acl == "private" || var.acl == "public-acl"
    error_message = "ACL must be either 'private' or 'public-acl'"
  }
}
