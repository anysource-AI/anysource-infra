output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - use this for DNS CNAME record"
  value       = module.private_alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer - use this for Route53 alias records"
  value       = module.private_alb.alb_zone_id
}

output "domain_name" {
  description = "The domain name configured for the application"
  value       = var.domain_name
}

output "application_url" {
  description = "The URL to access the application (domain if provided, otherwise ALB DNS name)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${module.private_alb.alb_dns_name}"
}
