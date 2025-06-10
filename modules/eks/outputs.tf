output "name" {
  description = "Name of the cluster"
  value       = module.eks.cluster_name
}
output "id" {
  description = "ID of the cluster"
  value       = module.eks.cluster_id
}


output "endpoint" {
  description = "The IP address of the cluster master."
  sensitive   = true
  value       = module.eks.cluster_endpoint
}
output "management_cluster_sg_id" {
  description = "Security group ID of the management cluster nodes"
  value       = module.eks.node_security_group_id
}

output "eks_ca" {
  description = "The base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "eks_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}
