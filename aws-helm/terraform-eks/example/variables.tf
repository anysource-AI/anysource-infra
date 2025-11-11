# ========================================
# Module Version Configuration
# ========================================

variable "release_version" {
  type        = string
  description = "Version/ref of the runlayer-infra module to use (e.g., v1.0.0, v1.1.0)"
  default     = "v1.0.0"
}

# ========================================
# Network Configuration Variables
# ========================================

# VPC Configuration (for existing VPC)
variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC (required when create_vpc = false)"
  default     = ""
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of existing private subnet IDs (required when create_vpc = false)"
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of existing public subnet IDs (required when create_vpc = false)"
  default     = []
}

# ========================================
# Existing EKS Cluster Configuration
# ========================================

variable "existing_cluster_name" {
  type        = string
  description = "Name of the existing EKS cluster (required when create_eks = false)"
  default     = ""
}

variable "existing_oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN of the existing EKS cluster (required when create_eks = false)"
  default     = ""
}

# ========================================
# Cluster Access Configuration
# ========================================

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  default     = []
}

# ========================================
# Database Configuration
# ========================================

variable "database_password" {
  type        = string
  description = "Master password for the database"
  sensitive   = true
}

# ========================================
# Application Secrets
# ========================================

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

variable "auth_api_key" {
  description = "Authentication API key for WorkOS"
  type        = string
  sensitive   = true
}

# ========================================
# EKS Namespace
# ========================================

variable "eks_namespace" {
  type        = string
  description = "Kubernetes namespace for the application"
  default     = "anysource-production"
}
