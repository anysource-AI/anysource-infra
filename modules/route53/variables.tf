variable "vpc_id" {
  type        = string
  description = "ID of the VPC for associating the private hosted zone"
}

variable "alb" {
  type = object({
    dns_name = string
    zone_id  = string
  })
  description = "Attributes of the ALB for creating the Route53 alias record"
}

variable "internal_url_name" {
  type        = string
  description = "Internal DNS name to register in the private hosted zone"
}