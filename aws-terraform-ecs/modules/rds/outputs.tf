output "cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = aws_rds_cluster.rds_cluster.endpoint
}

output "cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = aws_rds_cluster.rds_cluster.reader_endpoint
}

output "cluster_identifier" {
  description = "RDS cluster identifier"
  value       = aws_rds_cluster.rds_cluster.cluster_identifier
}

output "database_name" {
  description = "Database name"
  value       = aws_rds_cluster.rds_cluster.database_name
}

output "cluster_parameter_group_name" {
  description = "RDS cluster parameter group name with SSL enforcement"
  value       = aws_rds_cluster_parameter_group.rds_cluster_pg.name
}

output "ssl_enforcement_enabled" {
  description = "Indicates if SSL enforcement is enabled (1 = required, 0 = optional)"
  value       = var.force_ssl
}

output "cluster_port" {
  description = "RDS cluster port"
  value       = aws_rds_cluster.rds_cluster.port
}
