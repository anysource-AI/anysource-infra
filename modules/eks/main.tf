module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "~> 19.0"
  cluster_name                    = var.cluster_name
  subnet_ids                      = var.subnet
  vpc_id                          = var.network
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    iam_role_additional_policies = {
      sqs            = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
      s3             = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
      sns            = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
      secretsmanager = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
      apigateway     = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
      sessionmanager = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
    use_custom_launch_template = false
    disk_size                  = 100

  }

  eks_managed_node_groups = var.eks_managed_node_groups

  node_security_group_additional_rules = var.management_cluster_sg_id != null ? {
    ingress_from_management = {
      description              = "Allow access from management cluster nodes"
      protocol                 = "-1"
      from_port                = 0
      to_port                  = 0
      type                     = "ingress"
      source_security_group_id = var.management_cluster_sg_id
    }
  } : {}

  cluster_security_group_additional_rules = var.management_cluster_sg_id != null ? {
    ingress_from_management_cluster = {
      description              = "Allow management cluster to access API server"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = var.management_cluster_sg_id
    }
  } : {}

}
