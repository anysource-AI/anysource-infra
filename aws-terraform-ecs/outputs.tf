output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - use this for DNS CNAME record"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer - use this for Route53 alias records"
  value       = module.alb.alb_zone_id
}

# Public ALB outputs (explicit aliases for clarity in dual ALB setup)
output "public_alb_dns_name" {
  description = "DNS name of the Public Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "public_alb_zone_id" {
  description = "Zone ID of the Public Application Load Balancer"
  value       = module.alb.alb_zone_id
}

# Internal ALB outputs (for dual ALB setup)
output "internal_alb_dns_name" {
  description = "DNS name of the Internal Application Load Balancer (only available when enable_dual_alb is true)"
  value       = var.enable_dual_alb ? module.alb_internal[0].alb_dns_name : null
}

output "internal_alb_zone_id" {
  description = "Zone ID of the Internal Application Load Balancer (only available when enable_dual_alb is true)"
  value       = var.enable_dual_alb ? module.alb_internal[0].alb_zone_id : null
}

output "application_url" {
  description = "The URL to access the application (must be HTTPS)"
  value       = "https://${var.domain_name}"
}

# Outputs for Terraform-based deployments via Worker
output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster for deploying new tasks"
  value       = module.ecs.ecs_cluster_arn
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = "${var.project}-${var.environment}-cluster"
}

output "vpc_id" {
  description = "The VPC ID where the cluster runs"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for deploying ECS tasks"
  value       = local.private_subnet_ids
}

output "ecs_task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  value       = module.iam.ecs_task_execution_role_arn
}

output "alb_https_listener_arn" {
  description = "ARN of the ALB HTTPS listener for Terraform deployments"
  value       = module.alb.alb_listener_https_arn
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB for allowing ingress traffic"
  value       = module.sg_alb.security_group_id
}

output "service_discovery_namespace_id" {
  description = "Service Discovery namespace ID for dynamic deployments"
  value       = aws_service_discovery_private_dns_namespace.deployments.id
}

output "service_discovery_namespace_name" {
  description = "Service Discovery namespace name for dynamic deployments"
  value       = aws_service_discovery_private_dns_namespace.deployments.name
}
output "customer_id" {
  description = "Customer identifier used for telemetry tagging (defaults to domain name)"
  value       = local.customer_id
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.roles_micro_services.ecs_task_role_arn
}

output "terraform_state_bucket_name" {
  description = "S3 bucket name for Terraform state storage"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_custom_images_ecr_repo_url" {
  description = "ECR repository URL for custom container images deployed via Terraform"
  value       = aws_ecr_repository.custom_images.repository_url
}

output "private_route_table_ids" {
  description = "Private route table IDs (only available when VPC is created by module, not when using existing_vpc_id)"
  value       = var.existing_vpc_id == null ? module.vpc[0].private_route_table_ids : null
}

output "public_route_table_id" {
  description = "Public route table ID (only available when VPC is created by module, not when using existing_vpc_id)"
  value       = var.existing_vpc_id == null ? module.vpc[0].public_route_table_id : null
}
