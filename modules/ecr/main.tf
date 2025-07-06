resource "aws_ecr_repository" "ecr_repository" {
  for_each = toset(var.ecr_repositories)
  name     = "${each.key}-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR Repository Policy to allow public read access
resource "aws_ecr_repository_policy" "ecr_repository_policy" {
  for_each   = toset(var.ecr_repositories)
  repository = aws_ecr_repository.ecr_repository[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPull"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  for_each = toset(var.ecr_repositories)
  repository = "${each.key}-${var.environment}"

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
depends_on = [aws_ecr_repository.ecr_repository]
}
