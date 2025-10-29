########################################################################################################################
# State Migration: Moved Blocks
########################################################################################################################
#
# These moved blocks handle the migration from non-count to count-based module paths.
# When existing environments run terraform plan/apply, these blocks tell Terraform to update
# the state file paths WITHOUT destroying and recreating resources.
#
# What happens:
# 1. Existing envs: Terraform sees "module.eks" in state, "module.eks[0]" in code
# 2. Moved block says: "These are the same resource, just update the state path"
# 3. No resources are destroyed or recreated
# 4. After migration, these blocks can remain (they're idempotent)
#
# IMPORTANT: We only move the top-level module. The EKS module's internal resources
# (like module.kms and module.eks_managed_node_group) will be automatically updated
# by Terraform when the parent module path changes from module.eks to module.eks[0].
# Attempting to move nested modules explicitly can cause cyclic dependency errors
# with the EKS module's own internal migration blocks.
#
########################################################################################################################

# Migrate main EKS module from module.eks to module.eks[0]
moved {
  from = module.eks
  to   = module.eks[0]
}

# Note: We don't need to explicitly move nested modules like:
# - module.eks.module.kms
# - module.eks.module.eks_managed_node_group
# These are handled automatically when the parent module.eks is moved to module.eks[0]

########################################################################################################################
# Migrate IRSA Roles to count-based paths
########################################################################################################################

# Migrate EBS CSI Driver IRSA role
moved {
  from = module.ebs_csi_driver_irsa_role
  to   = module.ebs_csi_driver_irsa_role[0]
}

# Migrate Load Balancer Controller IRSA role
moved {
  from = module.load_balancer_controller_irsa_role
  to   = module.load_balancer_controller_irsa_role[0]
}

# Migrate CloudWatch Observability IRSA role
moved {
  from = module.cloudwatch_observability_irsa_role
  to   = module.cloudwatch_observability_irsa_role[0]
}

# Migrate EKS Cluster Service role
moved {
  from = module.eks_cluster_service_role
  to   = module.eks_cluster_service_role[0]
}

