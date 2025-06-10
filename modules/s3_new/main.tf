

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.project}-${var.environment}-${var.name}"
}


resource "aws_s3_bucket_ownership_controls" "owner" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "public_acess_block" {
  bucket = aws_s3_bucket.s3_bucket.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.owner,
    aws_s3_bucket_public_access_block.public_acess_block,
  ]

  bucket = aws_s3_bucket.s3_bucket.id
  acl    = "public-read"
}

# resource "aws_s3_bucket_policy" "bucket_policy" {
#   bucket = aws_s3_bucket.s3_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "DenyListBucketForPublic"
#         Effect = "Deny"
#         Principal = "*"
#         Action = "s3:ListBucket"
#         Resource = aws_s3_bucket.s3_bucket.arn
#         Condition = {
#           StringNotEquals = {
#             "aws:PrincipalType" = "AWS"
#           }
#           ArnNotLike = {
#             "aws:PrincipalArn" = "arn:aws:iam::*:user/*"
#           }
#         }
#       },
#       {
#         Sid = "AllowSpecificActions"
#         Effect = "Allow"
#         Principal = "*"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject"
#         ]
#         Resource = "${aws_s3_bucket.s3_bucket.arn}/*"
#       }
#     ]
#   })
# }
