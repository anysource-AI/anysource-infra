locals {
  prefix_target_group_length = var.environment == "production" ? 17 : 24
}
resource "aws_lb" "alb" {
  name                       = var.name
  internal                   = var.internal
  load_balancer_type         = var.load_balancer_type
  subnets                    = var.subnets
  security_groups            = var.security_groups
  idle_timeout               = 120
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "alb_target_group" {
  for_each    = var.target_groups
  name        = "${substr(each.key, 0, min(length(each.key), local.prefix_target_group_length))}-tg-${var.environment}" // if future problem occur, pay attention that can do "local" that separate production and stg by length.
  port        = each.value.port
  protocol    = each.value.protocol
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path     = each.value.health_check_path
    protocol = each.value.protocol
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.id
  port              = 80
  protocol          = "HTTP"
  # Temporarily comment out SSL settings
  # ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No routes defined"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn = aws_lb.alb.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No routes defined"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "alb_listener_rule" {
  for_each     = var.target_groups
  listener_arn = aws_lb_listener.alb_listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group[each.key].arn
  }
  condition {
    path_pattern {
      values = each.value.path_pattern
    }
  }
}

resource "aws_lb_listener_rule" "alb_listener_rule_https" {
  for_each     = var.target_groups
  listener_arn = aws_lb_listener.alb_listener_https.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group[each.key].arn
  }
  condition {
    path_pattern {
      values = each.value.path_pattern
    }
  }
}
