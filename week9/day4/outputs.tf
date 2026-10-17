output "bucket_name" {
  description = "Name of the temporary Day 4 bucket"
  value       = aws_s3_bucket.day4.id
}

output "bucket_arn" {
  description = "ARN of the temporary Day 4 bucket"
  value       = aws_s3_bucket.day4.arn
}
