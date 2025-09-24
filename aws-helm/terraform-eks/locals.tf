########################################################################################################################
# Local Values
########################################################################################################################

locals {
  # Basic naming and tagging
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${local.name_prefix}"

  # Use provided subnet IDs or discover from data sources
  private_subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : (
    length(data.aws_subnets.private) > 0 && length(data.aws_subnets.private[0].ids) > 0 ? data.aws_subnets.private[0].ids : []
  )
  public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : (
    length(data.aws_subnets.public) > 0 && length(data.aws_subnets.public[0].ids) > 0 ? data.aws_subnets.public[0].ids : []
  )

  # Common tags
  common_tags = merge({
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    ClusterName = local.cluster_name
  }, var.additional_tags)

  # Node group defaults based on environment
  node_group_defaults = {
    capacity_type  = "ON_DEMAND"
    disk_size      = var.environment == "production" ? 50 : 20
    instance_types = var.environment == "production" ? ["m6i.2xlarge", "m6i.4xlarge"] : ["m6i.xlarge", "m6i.2xlarge"]

    # Security and maintenance
    enable_monitoring = true

    # Block device mappings for security
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = var.environment == "production" ? 50 : 20
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 150
          encrypted             = true
          delete_on_termination = true
        }
      }
    }

    # Network interface
    # Note: enable_bootstrap_user_data should only be true when using custom AMI
    # For EKS managed node groups with default AMI, this should be false
    enable_bootstrap_user_data = false

    # Launch template
    create_launch_template          = true
    launch_template_use_name_prefix = true

    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "enabled"
    }
  }

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
}
