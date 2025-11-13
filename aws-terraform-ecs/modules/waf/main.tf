resource "aws_wafv2_ip_set" "allowlist_ipv4" {
  count              = var.enable_ip_allowlisting && length(var.allowlist_ipv4_cidrs) > 0 ? 1 : 0
  name               = "${var.name}-${var.project}-${var.environment}-allowlist-ipv4"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.allowlist_ipv4_cidrs
}

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

  # IP Allowlist Rule (Priority 0) - Only created when allowlisting is enabled
  dynamic "rule" {
    for_each = var.enable_ip_allowlisting && length(var.allowlist_ipv4_cidrs) > 0 ? [1] : []
    content {
      name     = "AllowlistedIPv4Only"
      priority = 0

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.allowlist_ipv4[0].arn
            }
          }
        }
      }

      visibility_config {
        sampled_requests_enabled   = var.sampled_requests
        cloudwatch_metrics_enabled = var.cloudwatch_metrics
        metric_name                = "${var.metric_name}-allowlist"
      }
    }
  }

  # AWS Managed Rules (Priority 1)
  dynamic "rule" {
    for_each = [1] # Always include this rule
    content {
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
}
resource "aws_wafv2_web_acl_association" "association" {
  count        = length(var.resources_arn)
  resource_arn = var.resources_arn[count.index]
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}
