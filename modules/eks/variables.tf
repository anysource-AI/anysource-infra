
variable "cluster_name" {
  type        = string
  description = "Name given to the new cluster"
}

variable "network" {
  type        = string
  description = "The VPC network name"
}

variable "subnet" {
  type        = list(string)
  description = "The VPC subnet name"
}


variable "node_groups" {
  type        = any
  description = "map of node groups config"
  default = {
    node_group_one = {
      desired_capacity = 2
      max_capacity     = 50
      min_capacity     = 1

      instance_type = "t3.medium"

      #tags         = ["aws-node"]
    }
  }
}

variable "node_tag" {
  type        = string
  description = "Machine tag for nodes"
}

variable "management_cluster_sg_id" {
  type        = string
  description = "Security group ID to allow access from management cluster nodes"
  default     = null
}

variable "eks_managed_node_groups" {
  type = map(object({
    name           = optional(string)
    instance_types = optional(list(string))
    desired_size   = optional(number)
    min_size       = optional(number)
    max_size       = optional(number)
    labels         = optional(map(string))
    tags           = optional(map(string))
  }))
  description = "Map of EKS managed node group configurations"
  default = {
    "node-group-1" = {
      name           = "node-group-1"
      instance_types = ["t3.xlarge"]
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      labels = {
        "node-group" = "node-group-1", "Name" = "node-group-1"
      }
      tags = {
        "node-group" = "node-group-1", "Name" = "node-group-1"
      }
    }
  }
}


