resource "aws_bedrock_guardrail" "guardrail" {
  name                      = "${var.project}-guardrail-${var.environment}"
  description               = "Bedrock guardrail for prompt attack detection"
  blocked_input_messaging   = "Input blocked due to prompt attack detection."
  blocked_outputs_messaging = "Output blocked due to prompt attack detection."

  cross_region_config {
    guardrail_profile_identifier = "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:guardrail-profile/us.guardrail.v1:0"
  }

  content_policy_config {
    tier_config {
      tier_name = "STANDARD"
    }

    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }

    filters_config {
      type            = "VIOLENCE"
      input_strength  = "NONE"
      output_strength = "NONE"
    }

    filters_config {
      type            = "HATE"
      input_strength  = "NONE"
      output_strength = "NONE"
    }

    filters_config {
      type            = "INSULTS"
      input_strength  = "NONE"
      output_strength = "NONE"
    }

    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "NONE"
      output_strength = "NONE"
    }

    filters_config {
      type            = "SEXUAL"
      input_strength  = "NONE"
      output_strength = "NONE"
    }
  }

  tags = merge(var.additional_tags, {
    Name        = "${var.project}-guardrail-${var.environment}"
    Environment = var.environment
    Project     = var.project
  })
}
