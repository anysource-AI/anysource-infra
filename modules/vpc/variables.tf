variable "region" {
  description = "The region to deploy the VPC"
  default     = "us-east-1"
}
variable "region_az" {
  description = "The region to deploy the VPC"
  type        = list(string)
}

variable "name" {
  description = "name of VPC"
}

variable "environment" {
  description = "environment"
  type        = string
}
variable "project" {
  description = "project name"
  default     = "anysource"
}

variable "cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}


variable "public_subnets" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
}

variable "private_subnets" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
}
variable "private_subnet_tags" {
  description = "Tags from outside the module in case there is"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Tags from outside the module for public subnets"
  type        = map(string)
  default     = {}
}
