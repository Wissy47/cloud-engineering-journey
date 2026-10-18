locals {
  bucket_name = "cloudlab-week9-day6-${var.bucket_suffix}"
}

resource "aws_s3_bucket" "lifecycle_lab" {
  bucket = local.bucket_name

  tags = {
    Name        = local.bucket_name
    Environment = "testing"
    ManagedBy   = "Terraform"
  }

}
