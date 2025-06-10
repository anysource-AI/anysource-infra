output "node_arn" {
  description = "The ARN of the EKS node IAM role"
  value       = aws_iam_role.eks_node_role.arn
}
