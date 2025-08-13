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

variable "vpc_cidr" {
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

variable "flow_log_cloudwatch_log_group_name" {
  description = "Name for the CloudWatch Log Group for VPC Flow Logs"
  type        = string
  default     = "/aws/vpc-flow-log/default"
}

variable "flow_log_cloudwatch_log_group_retention_in_days" {
  description = "Retention period for VPC Flow Logs in days"
  type        = number
  default     = 30
}

variable "flow_log_iam_role_name" {
  description = "Name for the IAM role used by VPC Flow Logs"
  type        = string
  default     = "vpc-flow-logs-role-default"
}

variable "flow_log_traffic_type" {
  description = "Type of traffic to capture in VPC Flow Logs (ALL, ACCEPT, REJECT)"
  type        = string
  default     = "ALL"
}
