output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - use this for DNS CNAME record"
  value       = module.private_alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer - use this for Route53 alias records"
  value       = module.private_alb.alb_zone_id
}

output "application_url" {
  description = "The URL to access the application (must be HTTPS)"
  value       = "https://${var.domain_name}"
}
