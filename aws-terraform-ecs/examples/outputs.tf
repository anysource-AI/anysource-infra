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

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_cluster.task_role_arn
}
