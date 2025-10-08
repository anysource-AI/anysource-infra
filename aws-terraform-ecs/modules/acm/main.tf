# Request and validate an SSL certificate from AWS Certificate Manager (ACM)
resource "aws_acm_certificate" "certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags = {
    Environment = var.environment
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Comment out validation for now - requires DNS setup
# resource "aws_acm_certificate_validation" "stg-api-certificate_validation" {
#   certificate_arn = aws_acm_certificate.certificate.arn
#   timeouts {
#     create = "5m"
#   }
# }
