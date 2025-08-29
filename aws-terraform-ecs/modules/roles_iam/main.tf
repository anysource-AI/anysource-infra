locals {
  environment     = var.environment == "production" ? "prod" : "stg"
  hash_production = "tAYIZg"
}

resource "aws_iam_role" "role" {
  for_each = toset(var.role_names)
  name     = "${var.project}-${var.environment}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ecs:${var.region}:${var.account}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "policy" {
  for_each    = toset(var.role_names)
  name        = "${var.project}-${var.environment}-${each.key}-policy"
  description = "Least privilege policy for ${var.project}-${var.environment}-${each.key}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": [
        "arn:aws:secretsmanager:${var.region}:${var.account}:secret:${var.project}-${local.environment}*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${var.project}-${var.environment}-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::${var.project}-${var.environment}-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:${var.region}:${var.account}:log-group:*-logs-${var.environment}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  for_each   = toset(var.role_names)
  role       = aws_iam_role.role[each.key].name
  policy_arn = aws_iam_policy.policy[each.key].arn
}
