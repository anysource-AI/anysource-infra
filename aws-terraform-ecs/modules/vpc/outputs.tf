output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnets" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "public_subnets" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_route_table_ids" {
  description = "List of private route table IDs (one per AZ)"
  value       = [for rt in aws_route_table.private : rt.id]
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}
