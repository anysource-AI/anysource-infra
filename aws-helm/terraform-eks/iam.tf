########################################################################################################################
# Enhanced Security Cluster Service Role
########################################################################################################################

# EKS cluster service role using terraform-aws-modules/iam/aws with enhanced security conditions
module "eks_cluster_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-cluster-service-role"

  # Create role for EKS service with enhanced security conditions
  trusted_role_services = ["eks.amazonaws.com"]

  # Enhanced security conditions to prevent confused deputy attacks
  custom_role_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          StringLike = {
            "aws:SourceArn" = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/*"
          }
        }
      }
    ]
  })

  # Attach the required EKS cluster policy
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]

  tags = local.common_tags
}

########################################################################################################################
# Enhanced Security Node Group Roles
########################################################################################################################

# EKS node group roles using terraform-aws-modules/iam/aws with enhanced security conditions
module "eks_node_group_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  for_each = var.node_groups

  # Enable role creation
  create_role = true
  role_name   = "${local.name_prefix}-${each.key}-node-group-role"

  # Create role for EC2 service with enhanced security conditions
  trusted_role_services = ["ec2.amazonaws.com"]

  # Enhanced security conditions to prevent confused deputy attacks
  custom_role_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = merge(local.common_trust_conditions, {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
          }
        })
      }
    ]
  })

  # Attach all required AWS managed policies for EKS node groups
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]

  tags = merge(local.common_tags, {
    NodeGroup = each.key
  })
}
