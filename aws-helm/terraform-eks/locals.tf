########################################################################################################################
# Local Values
########################################################################################################################

locals {
  # Basic naming and tagging
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = var.create_eks ? (var.cluster_name != "" ? var.cluster_name : "${local.name_prefix}") : var.existing_cluster_name

  # EKS cluster details - from created or existing cluster
  cluster_endpoint                   = var.create_eks ? module.eks[0].cluster_endpoint : data.aws_eks_cluster.existing[0].endpoint
  cluster_certificate_authority_data = var.create_eks ? module.eks[0].cluster_certificate_authority_data : data.aws_eks_cluster.existing[0].certificate_authority[0].data
  oidc_provider_arn                  = var.create_eks ? module.eks[0].oidc_provider_arn : var.existing_oidc_provider_arn

  # VPC selection - use created VPC or existing VPC
  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id

  # Subnet selection - use created subnets or existing subnets
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : (
    length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : (
      length(data.aws_subnets.private) > 0 && length(data.aws_subnets.private[0].ids) > 0 ? data.aws_subnets.private[0].ids : []
    )
  )
  public_subnet_ids = var.create_vpc ? module.vpc[0].public_subnets : (
    length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : (
      length(data.aws_subnets.public) > 0 && length(data.aws_subnets.public[0].ids) > 0 ? data.aws_subnets.public[0].ids : []
    )
  )

  # Availability zones
  availability_zones = length(var.region_az) > 0 ? var.region_az : slice(data.aws_availability_zones.available.names, 0, 3)

  # Common tags
  common_tags = merge({
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    ClusterName = local.cluster_name
  }, var.additional_tags)

  # Default security group rules when whitelist IPs are provided
  default_cluster_security_group_rules = length(var.whitelist_ips) > 0 ? {
    whitelist_ip_access = {
      description = "Allow HTTPS access from whitelist IPs to EKS control plane"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = var.whitelist_ips
    }
  } : {}

  # Default node security group rules for better security
  default_node_security_group_rules = {
    # Ingress rules
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to node all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 65535
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_node_to_node_all_traffic = {
      description = "Node to node all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
  }

  # Common security conditions for IAM trust relationships to prevent "confused deputy" attacks
  # These conditions ensure that only authorized principals can assume roles
  common_trust_conditions = {
    # Restricts role assumption to this specific AWS account only
    StringEquals = {
      "aws:SourceAccount" = data.aws_caller_identity.current.account_id
    }
  }

  # Merge cluster addons with IRSA role ARNs (only when creating EKS)
  cluster_addons_with_irsa = var.create_eks ? merge(
    var.cluster_addons,
    {
      aws-ebs-csi-driver = merge(
        try(var.cluster_addons["aws-ebs-csi-driver"], {}),
        {
          service_account_role_arn = module.ebs_csi_driver_irsa_role[0].arn
        }
      )
      amazon-cloudwatch-observability = merge(
        try(var.cluster_addons["amazon-cloudwatch-observability"], {}),
        {
          service_account_role_arn = module.cloudwatch_observability_irsa_role[0].arn
        }
      )
    }
  ) : {}
}
