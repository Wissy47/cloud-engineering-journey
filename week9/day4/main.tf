resource "aws_s3_bucket" "day4" {
  bucket = "${var.project_name}-week9-day4-${var.bucket_suffix}"

  tags = {
    Name      = "${var.project_name}-week9-day4"
    Lab       = "Week9Day4"
    ManagedBy = "Terraform"
  }
}
