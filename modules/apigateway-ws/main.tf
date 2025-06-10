resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.project}-${var.name}-${var.environment}"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = var.route_selection_expression
}

resource "aws_apigatewayv2_stage" "websocket" {
  api_id      = aws_apigatewayv2_api.websocket.id
  name        = "${var.project}-${var.name}-${var.environment}"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "websocket" {
  for_each           = { for k, v in var.routes : k => v if v.enabled }
  api_id             = aws_apigatewayv2_api.websocket.id
  integration_type   = each.value.integration_type
  integration_uri    = "${var.target_url}/${each.value.path}"
  integration_method = var.integration_method

  # Only include content_handling_strategy when explicitly set
  content_handling_strategy = each.value.content_handling_strategy

  # Only include template_selection_expression when request_templates are provided
  template_selection_expression = each.value.request_templates != null ? "\\$default" : null

  # Only include request_templates when they are actually provided
  request_templates = each.value.request_templates
}
# Create integration responses dynamically
resource "aws_apigatewayv2_integration_response" "websocket" {
  for_each                      = { for k, v in var.routes : k => v if v.integration_response }
  api_id                        = aws_apigatewayv2_api.websocket.id
  integration_id                = aws_apigatewayv2_integration.websocket[each.key].id
  integration_response_key      = "$default"
  template_selection_expression = "\\$default"
  response_templates = {
    "$default" = "$input.json('$')"
  }
}

# Create route responses dynamically
resource "aws_apigatewayv2_route_response" "websocket" {
  for_each           = { for k, v in var.routes : k => v if v.route_response }
  api_id             = aws_apigatewayv2_api.websocket.id
  route_id           = aws_apigatewayv2_route.routes[each.key].id
  route_response_key = "$default"
}



# Create routes dynamically
resource "aws_apigatewayv2_route" "routes" {
  for_each = { for k, v in var.routes : k => v if v.enabled }

  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = each.value.route_key
  target    = "integrations/${aws_apigatewayv2_integration.websocket[each.key].id}"
}

# Create a new IAM role for WebSocket API
resource "aws_iam_role" "websocket_role" {
  name = "${var.project}-role-${var.environment}-${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy for execute-api:ManageConnections
resource "aws_iam_role_policy" "websocket_policy" {
  name = "${var.project}-policy-${var.environment}-${var.name}"
  role = aws_iam_role.websocket_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = "${aws_apigatewayv2_api.websocket.execution_arn}/*"
      }
    ]
  })
}
