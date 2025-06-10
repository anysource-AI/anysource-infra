output "target_groups" {
  description = "ALB target groups for service routing"
  value       = aws_lb_target_group.alb_target_group
}

output "alb_listener" {
  description = "ALB listener for handling incoming requests"
  value       = aws_lb_listener.alb_listener
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.alb.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.alb.zone_id
}
