variable "project" {
  type        = string
  description = "The name of the application"
}

variable "environment" {
  type        = string
  description = "The environment for the application"
  validation {
    condition     = can(regex("^stg|prod|dr|production|eu$", var.environment))
    error_message = "Invalid environment. Must be either 'stg' or 'prod'"
  }
}

variable "engine_version" {
  type        = string
  description = "The version of the database engine"
}

variable "availability_zones" {
  type        = list(string)
  description = "The availability_zones of the database engine"
}
variable "name" {
  type        = string
  default     = "anysource"
  description = "The name of the database"
}

variable "min_capacity" {
  type        = string
  description = "The min capacity of the vCPU"
}
variable "max_capacity" {
  type        = string
  description = "The max capacity of the vCPU"
}

variable "publicly_accessible" {
  type        = bool
  description = "The publicly accessible of the database"
}

variable "subnet_ids" {
  type        = list(string)
  description = "The subnet_ids id of the database"
}

variable "vpc_id" {
  type        = string
  description = "The vpc_id of the database"
}

variable "count_replicas" {
  type        = number
  default     = 2
  description = "The number of RDS instances to create"
}

variable "secret_arn" {
  type        = string
  description = "The ARN of the AWS Secrets Manager secret containing database credentials"
}

variable "performance_insights_kms_key_id" {
  type        = string
  description = "The ARN of the KMS key to encrypt Performance Insights data"
  default     = null
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}
