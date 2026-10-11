output "bucket_name" {
  description = "Name of the Terraform Day 1 S3 bucket"
  value       = aws_s3_bucket.day1.bucket
}

output "bucket_arn" {
  description = "ARN of the Terraform Day 1 S3 bucket"
  value       = aws_s3_bucket.day1.arn
}
