# ========================================
# Outputs - Works for both MODE 1 and MODE 2
# ========================================

# Common outputs (available in both modes)
output "application_service_account_role_arn" {
  description = "ARN of the IAM role for application service account (IRSA)"
  value       = module.eks_cluster.application_service_account_role_arn
}

output "bedrock_guardrail_arn" {
  description = "ARN of the Bedrock guardrail"
  value       = module.eks_cluster.bedrock_guardrail_arn
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.eks_cluster.database_endpoint
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.eks_cluster.redis_endpoint
}

output "database_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = module.eks_cluster.database_secret_arn
}

# ========================================
# MODE 1 Only Outputs (New EKS Cluster)
# ========================================
# These outputs are only available when MODE 1 is active (create_eks = true)
# Comment out these outputs when using MODE 2 (existing EKS cluster)

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
}

output "load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller (IRSA)"
  value       = module.eks_cluster.load_balancer_controller_role_arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.eks_cluster.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.eks_cluster.private_subnet_ids
}
