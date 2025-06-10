resource "aws_wafv2_web_acl" "waf" {
  name        = "${var.name}-${var.project}-${var.environment}"
  description = "waf that for ${var.name} in env ${var.environment}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics
    metric_name                = var.metric_name
    sampled_requests_enabled   = var.sampled_requests
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = var.sampled_requests
      cloudwatch_metrics_enabled = var.cloudwatch_metrics
      metric_name                = "${var.metric_name}-badinputs"
    }
  }
}
resource "aws_wafv2_web_acl_association" "association" {
  count = length(var.resources_arn)
  resource_arn = var.resources_arn[count.index]
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}