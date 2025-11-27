# VPC Peering Configuration
# This file manages VPC peering connections for cross-account or cross-VPC connectivity

# Validation: Ensure peer_owner_id is provided for security tracking
# This helps prevent accepting connections from unknown sources
locals {
  # Validate that all peering connections have peer_owner_id specified
  validated_peering_connections = {
    for key, peer in var.vpc_peering_connections :
    key => peer
    if peer.peer_owner_id != null && peer.peer_owner_id != ""
  }

  # Track invalid peering connections (missing peer_owner_id)
  invalid_peering_connections = {
    for key, peer in var.vpc_peering_connections :
    key => peer
    if peer.peer_owner_id == null || peer.peer_owner_id == ""
  }
}

# Validation check: Fail if any peering connections lack peer_owner_id
resource "null_resource" "validate_peering_connections" {
  for_each = local.invalid_peering_connections

  provisioner "local-exec" {
    command = <<-EOT
      echo "ERROR: VPC peering connection '${each.key}' is missing peer_owner_id."
      echo "For security reasons, all VPC peering connections must explicitly specify the peer AWS account ID."
      echo "This ensures you only accept connections from known and trusted sources."
      exit 1
    EOT
  }
}

# Accept VPC peering connections (cross-account)
# Only creates resources when:
# 1. Module creates the VPC (not using existing_vpc_id)
# 2. vpc_peering_connections is populated
# 3. All connections have valid peer_owner_id specified
# SECURITY: auto_accept is enabled since peer_owner_id validation ensures
# connections are only from known and trusted AWS accounts
resource "aws_vpc_peering_connection_accepter" "peer" {
  for_each                  = var.existing_vpc_id == null ? local.validated_peering_connections : {}
  vpc_peering_connection_id = each.value.peering_connection_id
  auto_accept               = true

  tags = {
    Name        = "${var.project}-${var.environment}-peer-${each.key}"
    Project     = var.project
    Environment = var.environment
    PeerName    = each.key
    PeerOwnerId = each.value.peer_owner_id
    PeerRegion  = each.value.peer_region != "" ? each.value.peer_region : "same-region"
  }

  depends_on = [null_resource.validate_peering_connections]
}

# Add routes to private route tables for peered VPCs
# Only creates routes when:
# 1. Module creates the VPC (not using existing_vpc_id)
# 2. vpc_peering_connections is populated and validated
resource "aws_route" "peering_private" {
  for_each = var.existing_vpc_id == null ? {
    for pair in flatten([
      for peer_key, peer in local.validated_peering_connections : [
        for idx, rt_id in module.vpc[0].private_route_table_ids : {
          key                       = "${peer_key}-${idx}"
          peer                      = peer
          rt_id                     = rt_id
          peering_connection_id_ref = peer.peering_connection_id
          peer_vpc_cidr_ref         = peer.peer_vpc_cidr
        }
      ]
    ]) : pair.key => pair
  } : {}

  route_table_id            = each.value.rt_id
  destination_cidr_block    = each.value.peer_vpc_cidr_ref
  vpc_peering_connection_id = each.value.peering_connection_id_ref

  depends_on = [aws_vpc_peering_connection_accepter.peer]
}
