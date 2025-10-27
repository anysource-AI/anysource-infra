########################################################################################################################
# Enhanced Security Cluster Service Role
########################################################################################################################

# EKS cluster service role using terraform-aws-modules/iam/aws with enhanced security conditions
# Only created when creating a new EKS cluster
module "eks_cluster_service_role" {
  count   = var.create_eks ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.2"

  name = "${local.name_prefix}-svc"

  # Enhanced security conditions to prevent confused deputy attacks
  trust_policy_permissions = {
    TrustEksService = {
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["eks.amazonaws.com"]
        }
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
        {
          test     = "StringLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/*"]
        }
      ]
    }
  }

  # Attach the required EKS cluster policy
  policies = {
    AmazonEKSClusterPolicy = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  }

  tags = local.common_tags
}

########################################################################################################################
# Enhanced Security Node Group Roles
########################################################################################################################

# EKS node group roles using terraform-aws-modules/iam/aws with enhanced security conditions
# Only created when creating a new EKS cluster
module "eks_node_group_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.2"

  for_each = var.create_eks ? var.node_groups : {}

  name = "${local.name_prefix}-${each.key}-node"

  # Enhanced security conditions to prevent confused deputy attacks
  trust_policy_permissions = {
    TrustEc2Service = {
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"]
        }
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"]
        }
      ]
    }
  }

  # Attach all required AWS managed policies for EKS node groups
  policies = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = merge(local.common_tags, {
    NodeGroup = each.key
  })
}

########################################################################################################################
# AWS EBS CSI Driver IAM Role
########################################################################################################################

# Only created when creating a new EKS cluster
# For existing clusters, IRSA roles should already be configured
module "ebs_csi_driver_irsa_role" {
  count   = var.create_eks ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name = "${local.name_prefix}-ebs-csi-role"

  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

########################################################################################################################
# AWS Load Balancer Controller IAM Role
########################################################################################################################

# Only created when creating a new EKS cluster
# For existing clusters, IRSA roles should already be configured
module "load_balancer_controller_irsa_role" {
  count   = var.create_eks ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name = "${local.name_prefix}-alb-role"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

########################################################################################################################
# Amazon CloudWatch Observability IAM Role
########################################################################################################################

# Only created when creating a new EKS cluster
# For existing clusters, IRSA roles should already be configured
module "cloudwatch_observability_irsa_role" {
  count   = var.create_eks ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name = "${local.name_prefix}-cwatch-obs-role"

  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }

  tags = local.common_tags
}

########################################################################################################################
# Application IAM Role (IRSA)
########################################################################################################################

# Always created - this is for the application to access Bedrock, S3, Secrets Manager, etc.
# This is different from EKS system component roles (EBS CSI, ALB Controller, CloudWatch)
# which should only be created when creating a new cluster
module "application_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name = "${local.name_prefix}-app"

  # Custom policy with Bedrock permissions
  policies = {
    application_policy = aws_iam_policy.application_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["${var.eks_namespace}:anysource"]
    }
  }

  tags = local.common_tags
}

# Custom IAM policy for application
# Always created - application needs these permissions regardless of cluster creation
resource "aws_iam_policy" "application_policy" {
  name        = "${local.name_prefix}-application-policy"
  description = "IAM policy for ${var.project} application with Bedrock Guardrails permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*-logs-*:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:CreateGuardrail",
          "bedrock:GetGuardrail",
          "bedrock:ListGuardrails",
          "bedrock:UpdateGuardrail",
          "bedrock:DeleteGuardrail",
          "bedrock:ApplyGuardrail",
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}
