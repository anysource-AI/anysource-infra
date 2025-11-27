# ========================================
# Outputs
# ========================================

# Common outputs (available in both modes)
output "application_url" {
  description = "The URL to access the application (HTTPS)"
  value       = module.ecs_cluster.application_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - use this for DNS CNAME record"
  value       = module.ecs_cluster.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer - use this for Route53 alias records"
  value       = module.ecs_cluster.alb_zone_id
}

# Public ALB outputs (explicit aliases for clarity in dual ALB setup)
output "public_alb_dns_name" {
  description = "DNS name of the Public Application Load Balancer"
  value       = module.ecs_cluster.public_alb_dns_name
}

output "public_alb_zone_id" {
  description = "Zone ID of the Public Application Load Balancer"
  value       = module.ecs_cluster.public_alb_zone_id
}

# Internal ALB outputs (for dual ALB setup)
output "internal_alb_dns_name" {
  description = "DNS name of the Internal Application Load Balancer (only available when enable_dual_alb is true)"
  value       = module.ecs_cluster.internal_alb_dns_name
}

output "internal_alb_zone_id" {
  description = "Zone ID of the Internal Application Load Balancer (only available when enable_dual_alb is true)"
  value       = module.ecs_cluster.internal_alb_zone_id
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_cluster.task_role_arn
}
