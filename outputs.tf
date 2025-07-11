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
  description = "The URL to access the application (uses correct protocol based on HTTPS configuration)"
  value       = "${local.enable_https ? "https" : "http"}://${var.domain_name != "" ? var.domain_name : module.private_alb.alb_dns_name}"
}

output "https_enabled" {
  description = "Whether HTTPS is enabled for the application"
  value       = local.enable_https
}
