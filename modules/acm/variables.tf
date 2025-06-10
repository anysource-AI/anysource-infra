variable "domain_name" {
  type        = string
  description = "The domain name associated with the ALB"
  validation {
    condition     = length(var.domain_name) > 0
    error_message = "Domain name must not be empty"
  }
}
variable "environment" {
  type        = string
  description = "The environment for the application"
  validation {
    condition     = can(regex("^stg|prod|dr|production|eu$", var.environment))
    error_message = "Invalid environment. Must be either 'stg' or 'prod'"
  }
}
