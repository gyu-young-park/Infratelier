resource "aws_s3_bucket" "this" {
    bucket_prefix = "my-backend-s3-bucket"
    force_destroy = true
}

resource "aws_s3_bucket_versioning" "this" {
    bucket = aws_s3_bucket.this.id
    versioning_configuration {
      status = "Enabled"
    }
}

output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}