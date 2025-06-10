variable "project" {
  type = string
}


variable "account" {
  type = number
}

variable "region" {
  type = string
}
variable "env_vars" {
  type = map(string)
  default = {}
}

variable "secret_vars" {
  type = map(string)
  default = {}
}
variable "environment" {
  type = string
}
variable "services_names" {
  type = list(string)
}
variable "ecs_task_execution_role_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}


variable "public_alb_security_group" {
  type = any
}


variable "public_alb_target_groups" {
  type = map(object({
    arn = string
  }))
}


variable "services_configurations" {
}
