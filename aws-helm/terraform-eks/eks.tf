########################################################################################################################
# EKS Cluster
########################################################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.public_subnet_ids

  # Cluster endpoint configuration
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Additional security group rules
  cluster_security_group_additional_rules = merge(
    local.default_cluster_security_group_rules,
    var.cluster_security_group_additional_rules
  )
  node_security_group_additional_rules = merge(
    local.default_node_security_group_rules,
    var.node_security_group_additional_rules
  )

  # Encryption configuration
  create_kms_key                  = var.enable_cluster_encryption
  kms_key_description             = "EKS Secret Encryption Key for ${local.cluster_name}"
  kms_key_deletion_window_in_days = var.environment == "production" ? 30 : 7
  enable_kms_key_rotation         = true
  kms_key_administrators          = var.kms_key_administrators

  cluster_encryption_config = var.enable_cluster_encryption ? {
    resources = ["secrets"]
  } : {}

  # Cluster addons
  cluster_addons = var.cluster_addons

  # Enable cluster logging
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cloudwatch_log_group_kms_key_id        = null

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    for name, config in var.node_groups : name => merge(local.node_group_defaults, {
      name                     = "${local.name_prefix}-${name}"
      launch_template_name     = "${substr(var.project, 0, 8)}-${substr(var.environment, 0, 4)}-${name}-lt"
      iam_role_name            = "${substr(var.project, 0, 8)}-${substr(var.environment, 0, 4)}-${name}-role"
      iam_role_use_name_prefix = false
      instance_types           = config.instance_types
      min_size                 = config.scaling_config.min_size
      max_size                 = config.scaling_config.max_size
      desired_size             = config.scaling_config.desired_size

      disk_size = config.disk_size

      labels = merge(config.labels, {
        Environment = var.environment
        NodeGroup   = name
      })

      taints = config.taints

      update_config = config.update_config

      # IAM role for nodes
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      tags = merge(local.common_tags, {
        NodeGroup = name
      })
    })
  }

  # Enable irsa
  enable_irsa = true

  # Enable cluster creator admin permissions for initial access
  enable_cluster_creator_admin_permissions = true

  tags = local.common_tags
}

########################################################################################################################
# AWS Load Balancer Controller IAM Role
########################################################################################################################

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "AmazonEKSLoadBalancerControllerRole"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

########################################################################################################################
# Anysource Application IAM Role (IRSA)
########################################################################################################################

module "anysource_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-anysource-role"

  # Custom policy with Bedrock permissions
  role_policy_arns = {
    anysource_policy = aws_iam_policy.anysource_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:anysource"]
    }
  }

  tags = local.common_tags
}

# Custom IAM policy for Anysource application
resource "aws_iam_policy" "anysource_policy" {
  name        = "${local.name_prefix}-anysource-policy"
  description = "IAM policy for Anysource application with Bedrock Guardrails permissions"

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
          "bedrock-runtime:ApplyGuardrail"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}
