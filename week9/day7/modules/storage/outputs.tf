output "bucket_id" {
  description = "ID of the artifact bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "bucket_arn" {
  description = "ARN of the artifact bucket"
  value       = aws_s3_bucket.artifacts.arn
}