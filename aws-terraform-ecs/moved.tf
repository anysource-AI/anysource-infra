# State migration for VPC module to support optional existing VPC
#
# This file handles the migration of VPC resources from module.vpc to module.vpc[0]
# for existing customers. When the VPC module was made conditional (count = 1 or 0),
# existing resources need to be moved to the new [0] indexed path to prevent recreation.
#
# For new customers using existing VPCs (existing_vpc_id is set), the VPC module won't
# be created at all (count = 0), so these moved blocks won't affect them.

# VPC
moved {
  from = module.vpc.aws_vpc.main
  to   = module.vpc[0].aws_vpc.main
}

# Internet Gateway
moved {
  from = module.vpc.aws_internet_gateway.main
  to   = module.vpc[0].aws_internet_gateway.main
}

# Private Subnets (assuming 3 AZs based on default configuration)
moved {
  from = module.vpc.aws_subnet.private[0]
  to   = module.vpc[0].aws_subnet.private[0]
}

moved {
  from = module.vpc.aws_subnet.private[1]
  to   = module.vpc[0].aws_subnet.private[1]
}

moved {
  from = module.vpc.aws_subnet.private[2]
  to   = module.vpc[0].aws_subnet.private[2]
}

# Public Subnets (assuming 3 AZs based on default configuration)
moved {
  from = module.vpc.aws_subnet.public[0]
  to   = module.vpc[0].aws_subnet.public[0]
}

moved {
  from = module.vpc.aws_subnet.public[1]
  to   = module.vpc[0].aws_subnet.public[1]
}

moved {
  from = module.vpc.aws_subnet.public[2]
  to   = module.vpc[0].aws_subnet.public[2]
}

# Elastic IPs for NAT Gateways
moved {
  from = module.vpc.aws_eip.nat[0]
  to   = module.vpc[0].aws_eip.nat[0]
}

moved {
  from = module.vpc.aws_eip.nat[1]
  to   = module.vpc[0].aws_eip.nat[1]
}

moved {
  from = module.vpc.aws_eip.nat[2]
  to   = module.vpc[0].aws_eip.nat[2]
}

# NAT Gateways
moved {
  from = module.vpc.aws_nat_gateway.nat_gw[0]
  to   = module.vpc[0].aws_nat_gateway.nat_gw[0]
}

moved {
  from = module.vpc.aws_nat_gateway.nat_gw[1]
  to   = module.vpc[0].aws_nat_gateway.nat_gw[1]
}

moved {
  from = module.vpc.aws_nat_gateway.nat_gw[2]
  to   = module.vpc[0].aws_nat_gateway.nat_gw[2]
}

# Public Route Table
moved {
  from = module.vpc.aws_route_table.public
  to   = module.vpc[0].aws_route_table.public
}

# Public Route Table Associations
moved {
  from = module.vpc.aws_route_table_association.public[0]
  to   = module.vpc[0].aws_route_table_association.public[0]
}

moved {
  from = module.vpc.aws_route_table_association.public[1]
  to   = module.vpc[0].aws_route_table_association.public[1]
}

moved {
  from = module.vpc.aws_route_table_association.public[2]
  to   = module.vpc[0].aws_route_table_association.public[2]
}

# Private Route Tables
moved {
  from = module.vpc.aws_route_table.private[0]
  to   = module.vpc[0].aws_route_table.private[0]
}

moved {
  from = module.vpc.aws_route_table.private[1]
  to   = module.vpc[0].aws_route_table.private[1]
}

moved {
  from = module.vpc.aws_route_table.private[2]
  to   = module.vpc[0].aws_route_table.private[2]
}

# Private Route Table Associations
moved {
  from = module.vpc.aws_route_table_association.private[0]
  to   = module.vpc[0].aws_route_table_association.private[0]
}

moved {
  from = module.vpc.aws_route_table_association.private[1]
  to   = module.vpc[0].aws_route_table_association.private[1]
}

moved {
  from = module.vpc.aws_route_table_association.private[2]
  to   = module.vpc[0].aws_route_table_association.private[2]
}

# VPC Flow Logs CloudWatch Log Group
moved {
  from = module.vpc.aws_cloudwatch_log_group.vpc_flow_logs
  to   = module.vpc[0].aws_cloudwatch_log_group.vpc_flow_logs
}

# VPC Flow Logs IAM Role
moved {
  from = module.vpc.aws_iam_role.vpc_flow_logs
  to   = module.vpc[0].aws_iam_role.vpc_flow_logs
}

# VPC Flow Logs IAM Role Policy Attachment
moved {
  from = module.vpc.aws_iam_role_policy_attachment.vpc_flow_logs
  to   = module.vpc[0].aws_iam_role_policy_attachment.vpc_flow_logs
}

# VPC Flow Log
moved {
  from = module.vpc.aws_flow_log.vpc
  to   = module.vpc[0].aws_flow_log.vpc
}
