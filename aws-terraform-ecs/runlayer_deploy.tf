# Runlayer Deploy Infrastructure
# Provides S3 storage for Terraform state and IAM permissions for worker-based deployments

# Service Discovery Private DNS Namespace for dynamic deployments
resource "aws_service_discovery_private_dns_namespace" "deployments" {
  name        = "${var.project}-${var.environment}-deployments.local"
  description = "Private DNS namespace for Runlayer Deploy service discovery"
  vpc         = local.vpc_id

  tags = {
    Name        = "${var.project}-deployments-namespace"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Service discovery for Runlayer Deploy"
  }
}

# S3 Bucket for Terraform State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project}-${var.environment}-deploy-tf-state"

  tags = {
    Name        = "${var.project}-deploy-tf-state"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Terraform state storage for Runlayer Deploy"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy to manage old state versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}


# IAM Policy for Terraform Deployment Operations
# Maximum security: ARN-based restrictions where possible, fallback to conditions where needed
resource "aws_iam_policy" "runlayer_deploy_policy" {
  name        = "${var.project}-${var.environment}-runlayer-deploy-policy"
  description = "Minimal permissions for worker to deploy runlayer infrastructure via Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 permissions - Terraform state bucket only
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      # ECS permissions - Restricted to specific cluster and runlayer-* resources
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:TagResource",
          "ecs:UntagResource"
        ]
        Resource = [
          # Specific cluster only
          module.ecs.ecs_cluster_arn,
          # Services with runlayer- prefix in specific cluster
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${module.ecs.cluster_name}/runlayer-*"
        ]
      },
      # ECS Task Definition permissions - Restricted to runlayer-* prefix
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:TagResource",
          "ecs:UntagResource"
        ]
        Resource = [
          # Task definitions with runlayer- prefix
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task-definition/runlayer-*:*"
        ]
      },
      # ECS Read-only and management permissions (needed for Terraform planning and cleanup)
      # Note: DeregisterTaskDefinition requires Resource = "*" per AWS API requirements
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
      },
      # ECS PassRole - Required to use existing task execution role
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          module.iam.ecs_task_execution_role_arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
      # EC2 Security Group - Create in specific VPC only
      # Note: CreateSecurityGroup requires permissions on both security-group and vpc resources
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:security-group/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:vpc/${local.vpc_id}"
        ]
      },
      # EC2 Tagging - Allow tagging during security group creation only
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
        }
      },
      # EC2 Security Group - Modify/delete only in specific VPC
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
          "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
          "ec2:ModifySecurityGroupRules"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:Vpc" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:vpc/${local.vpc_id}"
          }
        }
      },
      # EC2 Tagging - For security groups in specific VPC only
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:Vpc" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:vpc/${local.vpc_id}"
          }
        }
      },
      # EC2 Read-only permissions (needed for VPC/network discovery)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      # Service Discovery - Write to specific namespace only
      {
        Effect = "Allow"
        Action = [
          "servicediscovery:CreateService",
          "servicediscovery:DeleteService",
          "servicediscovery:UpdateService",
          "servicediscovery:GetService",
          "servicediscovery:RegisterInstance",
          "servicediscovery:DeregisterInstance",
          "servicediscovery:TagResource",
          "servicediscovery:UntagResource"
        ]
        Resource = [
          # Specific namespace
          aws_service_discovery_private_dns_namespace.deployments.arn,
          # All services in the region (will be restricted by namespace in practice)
          "arn:aws:servicediscovery:${var.region}:${data.aws_caller_identity.current.account_id}:service/*"
        ]
      },
      # Service Discovery - Read operations (no conditions needed for read-only)
      {
        Effect = "Allow"
        Action = [
          "servicediscovery:GetNamespace",
          "servicediscovery:ListServices",
          "servicediscovery:ListNamespaces",
          "servicediscovery:ListTagsForResource"
        ]
        Resource = "*"
      },
      # CloudWatch Logs - Restricted to /ecs/runlayer-* pattern
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/runlayer-*:*"
      },
      # CloudWatch Logs - Read operations
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      # ECR - Read-only access for pulling images
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      # ECR - Push to custom-images repository only
      {
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.custom_images.arn
      }
    ]
  })
}

# Attach deployment policy to existing worker task role
resource "aws_iam_role_policy_attachment" "worker_runlayer_deploy" {
  role       = module.roles_micro_services.ecs_task_role_name
  policy_arn = aws_iam_policy.runlayer_deploy_policy.arn
}

resource "aws_ecr_repository" "custom_images" {
  name                 = "${var.project}-${var.environment}-custom-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project}-custom-images"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Custom container images for Terraform deployments"
  }
}

resource "aws_ecr_lifecycle_policy" "custom_images" {
  repository = aws_ecr_repository.custom_images.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

