# ALB Security Group with configurable access
module "sg_alb" {
  source      = "./modules/security-group"
  name        = "${var.project}-${var.alb_access_type}-alb"
  description = "${var.project} ${var.alb_access_type} ALB security group"
  vpc_id      = local.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.alb_access_type == "private" ? [var.vpc_cidr] : var.alb_allowed_cidrs
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.alb_access_type == "private" ? [var.vpc_cidr] : var.alb_allowed_cidrs
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
