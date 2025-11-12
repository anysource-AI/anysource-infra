variable "domain_name" {
  type        = string
  description = "The domain name associated with the ALB"
  validation {
    condition     = length(var.domain_name) > 0
    error_message = "Domain name must not be empty"
  }
}

variable "hosted_zone_name" {
  type        = string
  description = "Optional Route53 hosted zone name used only when enable_acm_dns_validation is true"
  default     = ""

  validation {
    condition     = var.enable_acm_dns_validation == false || length(var.hosted_zone_name) > 0
    error_message = "When enable_acm_dns_validation is true, hosted_zone_name must be provided for Route53 zone lookup."
  }
}

variable "environment" {
  type        = string
  description = "The environment for the application"
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty"
  }
}

variable "enable_acm_dns_validation" {
  type        = bool
  description = "Whether to automatically validate the ACM certificate via Route53"
  default     = false
}
