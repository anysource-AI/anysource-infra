output "ecr_repositories" {
  value = [for repository in aws_ecr_repository.ecr_repository : repository.repository_url]
}

output "ecr_repository_urls" {
  value = {
    for k, v in aws_ecr_repository.ecr_repository : k => v.repository_url
  }
  description = "Map of service names to ECR repository URLs"
}

output "ecr_repository_names" {
  value = {
    for k, v in aws_ecr_repository.ecr_repository : k => v.name
  }
  description = "Map of service names to ECR repository names"
}
