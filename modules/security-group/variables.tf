variable "name" {
  type        = string
  description = "Name of the security group"
  validation {
    condition     = length(var.name) > 0
    error_message = "Security group name cannot be empty."
  }
}

variable "description" {
  type        = string
  description = "Enter a description for the security group"
  validation {
    condition     = length(var.description) > 0
    error_message = "You need to enter a description"
  }
}

variable "vpc_id" {
  type = string
}

variable "ingress_rules" {
  type = list(object({
    from_port       = number
    to_port         = number
    cidr_blocks     = list(string)
    protocol        = string
    security_groups = optional(list(string), [])
  }))
}

variable "egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
    protocol    = string
  }))
}
