# ASG CPU CloudWatch Alarm Tuning Variables
variable "asg_cpu_evaluation_periods" {
  type        = number
  description = "Evaluation periods for ASG CPU utilization alarm."
  default     = 1
}

variable "asg_cpu_threshold" {
  type        = number
  description = "Threshold for ASG CPU utilization alarm."
  default     = 80
}

variable "asg_cpu_alarm_period" {
  type        = number
  description = "Period (in seconds) for ASG CPU utilization alarm."
  default     = 60
}
# CloudWatch ALB Alarm Tuning Variables
variable "alb_5xx_threshold" {
  type        = number
  description = "Threshold for ALB 5xx error alarm."
  default     = 20
}

variable "alb_alarm_period" {
  type        = number
  description = "Period (in seconds) for ALB alarms."
  default     = 300
}

variable "alb_unhealthy_evaluation_periods" {
  type        = number
  description = "Evaluation periods for ALB unhealthy host count alarm."
  default     = 1
}

variable "alb_unhealthy_threshold" {
  type        = number
  description = "Threshold for ALB unhealthy host count alarm."
  default     = 1
}

variable "alb_latency_evaluation_periods" {
  type        = number
  description = "Evaluation periods for ALB latency alarm."
  default     = 1
}

variable "alb_latency_threshold" {
  type        = number
  description = "Threshold for ALB latency alarm."
  default     = 1
}
########################################################################################################################
# Application - Core Required Variables
########################################################################################################################

variable "region" {
  type        = string
  description = "AWS region"
}

variable "profile" {
  type        = string
  description = "AWS profile"
  default     = "default"
}

variable "project" {
  type        = string
  description = "Project name"
  default     = "anysource"
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development"
  }
}

variable "account" {
  type        = string
  description = "AWS Account ID"
}

########################################################################################################################
# Network Configuration
########################################################################################################################

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where EKS cluster will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS cluster"
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for EKS cluster (optional)"
  default     = []
}

########################################################################################################################
# EKS Configuration
########################################################################################################################

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = ""
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version to use for the EKS cluster"
  default     = "1.33"
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  default     = true
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  default     = []

  validation {
    condition = length(var.cluster_endpoint_public_access_cidrs) == 0 || alltrue([
      for cidr in var.cluster_endpoint_public_access_cidrs :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid IPv4 CIDR notation."
  }
}

variable "whitelist_ips" {
  type        = list(string)
  description = "List of IP addresses/CIDR blocks to whitelist for EKS cluster access"
  default     = []
  validation {
    condition = length(var.whitelist_ips) > 0 && alltrue([
      for ip in var.whitelist_ips : (
        can(cidrhost(ip, 0)) || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", ip))
      )
    ])
    error_message = "whitelist_ips must not be empty and each entry must be a valid IPv4 address or CIDR block."
  }
}

variable "cluster_security_group_additional_rules" {
  type = map(object({
    description                   = string
    protocol                      = string
    from_port                     = number
    to_port                       = number
    type                          = string
    cidr_blocks                   = optional(list(string))
    source_security_group_id      = optional(string)
    source_cluster_security_group = optional(bool)
  }))
  description = "Additional security group rules to add to the cluster security group created"
  default     = {}
}

variable "node_security_group_additional_rules" {
  type = map(object({
    description                   = string
    protocol                      = string
    from_port                     = number
    to_port                       = number
    type                          = string
    cidr_blocks                   = optional(list(string))
    source_security_group_id      = optional(string)
    source_cluster_security_group = optional(bool)
  }))
  description = "Additional security group rules to add to the node security group created"
  default     = {}
}

variable "enable_cluster_encryption" {
  type        = bool
  description = "Enable encryption of kubernetes secrets"
  default     = true
}

variable "kms_key_administrators" {
  type        = list(string)
  description = "List of IAM ARNs for users/roles that can administer the KMS key"
  default     = []
}

########################################################################################################################
# Logging Configuration
########################################################################################################################

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "List of EKS cluster log types to enable"
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  validation {
    condition = alltrue([
      for log_type in var.cluster_enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Log types must be one of: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "cloudwatch_log_group_retention_in_days" {
  type        = number
  description = "Number of days to retain log events in CloudWatch"
  default     = 400

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_group_retention_in_days)
    error_message = "CloudWatch log retention must be one of the valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}

########################################################################################################################
# Node Groups Configuration
########################################################################################################################

variable "enable_spot_instances" {
  type        = bool
  description = "Enable spot instances for cost optimization (not recommended for production)"
  default     = false
}

variable "spot_instance_interruption_behavior" {
  type        = string
  description = "Behavior when a spot instance is interrupted"
  default     = "terminate"

  validation {
    condition     = contains(["hibernate", "stop", "terminate"], var.spot_instance_interruption_behavior)
    error_message = "Spot instance interruption behavior must be one of: hibernate, stop, terminate."
  }
}

variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type = map(object({
    instance_types = list(string)
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
    update_config = optional(object({
      max_unavailable_percentage = optional(number, 25)
    }), {})
    disk_size = optional(number, 20)
    labels    = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
  default = {
    default = {
      instance_types = ["t3.medium"]
      scaling_config = {
        desired_size = 2
        max_size     = 4
        min_size     = 1
      }
      disk_size = 20
    }
  }
  validation {
    condition = alltrue([
      for ng in var.node_groups : (
        ng.scaling_config.min_size <= ng.scaling_config.desired_size &&
        ng.scaling_config.desired_size <= ng.scaling_config.max_size
      )
    ])
    error_message = "Each node group's scaling_config must satisfy: min_size ≤ desired_size ≤ max_size."
  }
}

########################################################################################################################
# ECR Configuration
########################################################################################################################

variable "ecr_repositories" {
  type        = map(string)
  description = "Map of service names to their ECR repository URIs"
  default     = {}

  validation {
    condition = alltrue([
      for service_name, uri in var.ecr_repositories :
      can(regex("^(public\\.ecr\\.aws/[^/]+/[^:]+:[^:]+|[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+)$", uri))
    ])
    error_message = "ECR repository URIs must be either public ECR (public.ecr.aws/namespace/repo:tag) or private ECR (account.dkr.ecr.region.amazonaws.com/repo:tag) format"
  }
}

########################################################################################################################
# Add-ons Configuration
########################################################################################################################

variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster"
  type = map(object({
    addon_version               = optional(string)
    configuration_values        = optional(string)
    preserve                    = optional(bool, true)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    tags                        = optional(map(string), {})
  }))
  default = {
    coredns = {
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    kube-proxy = {
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    vpc-cni = {
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    aws-ebs-csi-driver = {
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
    eks-pod-identity-agent = {
      preserve                    = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
  }
}

########################################################################################################################
# Application-specific Configuration (Optional)
########################################################################################################################

variable "domain_name" {
  type        = string
  description = "Domain name for the application (optional)"
  default     = ""
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}

