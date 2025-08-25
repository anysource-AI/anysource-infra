

resource "aws_s3_bucket" "s3_buckets" {
  bucket = "${var.project}-${var.environment}-${var.name}"
  acl    = var.acl
}
