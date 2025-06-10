output "api_endpoint" {
  value = aws_apigatewayv2_api.websocket.api_endpoint
}

output "execution_arn" {
  value = aws_apigatewayv2_api.websocket.execution_arn
}
