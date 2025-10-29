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

variable "create_vpc" {
  type        = bool
  description = "Whether to create a new VPC or use an existing one"
  default     = true
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where EKS cluster will be created (required when create_vpc = false)"
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (used when create_vpc = true)"
  default     = "10.0.0.0/16"
}

variable "region_az" {
  type        = list(string)
  description = "Availability zones to use (auto-discovered if empty)"
  default     = []
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDR blocks (used when create_vpc = true)"
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDR blocks (used when create_vpc = true)"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS cluster (used when create_vpc = false)"
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for EKS cluster (used when create_vpc = false)"
  default     = []
}

########################################################################################################################
# EKS Configuration
########################################################################################################################

variable "create_eks" {
  type        = bool
  description = "Whether to create the EKS cluster"
  default     = true
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster (used when create_eks = true)"
  default     = ""
}

variable "existing_cluster_name" {
  type        = string
  description = "Name of existing EKS cluster (required when create_eks = false)"
  default     = ""

  validation {
    condition     = var.create_eks || (var.existing_cluster_name != "")
    error_message = "existing_cluster_name is required when create_eks = false"
  }
}

variable "existing_oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN of existing EKS cluster (required when create_eks = false)"
  default     = ""

  validation {
    condition     = var.create_eks || (var.existing_oidc_provider_arn != "")
    error_message = "existing_oidc_provider_arn is required when create_eks = false"
  }
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version to use for the EKS cluster (used when create_eks = true)"
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
  description = "List of IP addresses/CIDR blocks to whitelist for EKS cluster access (optional, use cluster_endpoint_public_access_cidrs for endpoint access)"
  default     = []
  validation {
    condition = alltrue([
      for ip in var.whitelist_ips : (
        can(cidrhost(ip, 0)) || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", ip))
      )
    ])
    error_message = "Each whitelist_ips entry must be a valid IPv4 address or CIDR block."
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
    disk_size = optional(number, 50)
    labels    = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string
    })), {})
  }))
  default = {
    default = {
      instance_types = ["m6i.2xlarge"]
      scaling_config = {
        desired_size = 6
        max_size     = 20
        min_size     = 4
      }
      disk_size = 50
      taints    = {}
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
    resolve_conflicts_on_update = optional(string, "PRESERVE")
    service_account_role_arn    = optional(string)
    before_compute              = optional(bool, false)
    tags                        = optional(map(string), {})
  }))
  default = {
    # Critical add-ons that MUST be installed AND active before nodes join
    # before_compute = true ensures add-on is fully ready before node groups start
    vpc-cni = {
      before_compute = true # CNI must be active for nodes to get network interfaces
    }
    kube-proxy = {
      before_compute = true # Network proxy needed for service communication
    }
    # Additional add-ons (can be installed alongside node group creation)
    aws-ebs-csi-driver              = {}
    eks-pod-identity-agent          = {}
    coredns                         = {}
    metrics-server                  = {}
    amazon-cloudwatch-observability = {}
    cert-manager                    = {}
  }
}

########################################################################################################################
# Application-specific Configuration (Optional)
########################################################################################################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}

########################################################################################################################
# Database Configuration
########################################################################################################################

variable "database_name" {
  type        = string
  description = "Name of the database to create"
  default     = "postgres"
}

variable "database_username" {
  type        = string
  description = "Master username for the database"
  default     = "postgres"
  sensitive   = true
}

variable "database_password" {
  type        = string
  description = "Master password for the database"
  sensitive   = true
}

variable "database_config" {
  type = object({
    engine_version      = optional(string, "16.8")
    min_capacity        = optional(number, 2)
    max_capacity        = optional(number, 16)
    force_ssl           = optional(bool, false)
    deletion_protection = optional(bool, false)
    skip_final_snapshot = optional(bool, false)
  })
  description = "Database configuration"
  default     = {}
}

########################################################################################################################
# Redis Configuration
########################################################################################################################

variable "redis_node_type" {
  type        = string
  description = "ElastiCache Redis node type"
  default     = "cache.t3.medium"
}


########################################################################################################################
# Application Secrets
########################################################################################################################

variable "secret_key" {
  type        = string
  description = "Secret key for application encryption"
  sensitive   = true
}

variable "master_salt" {
  type        = string
  description = "Master salt for application hashing"
  sensitive   = true
}

variable "sentry_dsn" {
  type        = string
  description = "Sentry DSN for error tracking"
  sensitive   = true
  default     = ""
}

variable "auth_api_key" {
  type        = string
  description = "Authentication API key"
  sensitive   = true
}

########################################################################################################################
# Monitoring Configuration
########################################################################################################################

variable "enable_monitoring" {
  type        = bool
  description = "Enable CloudWatch monitoring and alarms"
  default     = false
}

########################################################################################################################
# S3 Configuration
########################################################################################################################

variable "buckets_conf" {
  type        = map(object({ acl = string }))
  description = "S3 bucket configurations"
  default     = {}
}

variable "eks_namespace" {
  type        = string
  description = "Kubernetes namespace for the application"
}

########################################################################################################################
# EKS Access Configuration
########################################################################################################################

variable "access_entries" {
  description = "Map of access entries to add to the cluster for API-based access control"
  type = map(object({
    principal_arn = string
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = optional(object({
        type       = optional(string, "cluster")
        namespaces = optional(list(string))
      }))
    })), {})
    kubernetes_groups = optional(list(string), [])
    type              = optional(string, "STANDARD")
  }))
  default = {}
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable automatic admin permissions for the IAM identity that creates the cluster (recommended for initial setup, disable when managing access entries explicitly)"
  type        = bool
  default     = true
}
