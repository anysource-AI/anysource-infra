########################################################################################################################
# Essential EKS Cluster Outputs
########################################################################################################################

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = local.cluster_endpoint
}

########################################################################################################################
# Authentication Outputs
########################################################################################################################

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = local.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for the EKS cluster"
  value       = local.oidc_provider_arn
}

########################################################################################################################
# IAM Role Outputs
########################################################################################################################

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for AWS EBS CSI Driver (IRSA) - only available when create_eks = true"
  value       = var.create_eks ? module.ebs_csi_driver_irsa_role[0].arn : null
}

output "application_service_account_role_arn" {
  description = "ARN of the IAM role for application service account (IRSA) - always created"
  value       = module.application_irsa_role.arn
}

output "load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller (IRSA) - only available when create_eks = true"
  value       = var.create_eks ? module.load_balancer_controller_irsa_role[0].arn : null
}

output "cloudwatch_observability_role_arn" {
  description = "ARN of the IAM role for Amazon CloudWatch Observability (IRSA) - only available when create_eks = true"
  value       = var.create_eks ? module.cloudwatch_observability_irsa_role[0].arn : null
}

########################################################################################################################
# VPC Outputs
########################################################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = local.public_subnet_ids
}

########################################################################################################################
# Database Outputs
########################################################################################################################

output "rds_cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = module.rds.cluster_reader_endpoint
  sensitive   = true
}

output "rds_cluster_id" {
  description = "RDS cluster identifier"
  value       = module.rds.cluster_id
}

########################################################################################################################
# Redis Outputs
########################################################################################################################

output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  sensitive   = true
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
  sensitive   = true
}

output "redis_replication_group_id" {
  description = "Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

########################################################################################################################
# Secrets Manager Outputs
########################################################################################################################

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = module.app_secrets.secret_arn
  sensitive   = true
}

output "secrets_manager_name" {
  description = "Name of the Secrets Manager secret"
  value       = module.app_secrets.secret_name
}

########################################################################################################################
# Bedrock Outputs
########################################################################################################################

output "bedrock_guardrail_id" {
  description = "ID of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.guardrail.guardrail_id
}

output "bedrock_guardrail_arn" {
  description = "ARN of the Bedrock guardrail"
  value       = aws_bedrock_guardrail.guardrail.guardrail_arn
}
