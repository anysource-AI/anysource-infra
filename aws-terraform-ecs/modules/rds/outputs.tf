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
