output "bucket_name" {
  description = "Name of the Day 2 S3 bucket"
  value       = aws_s3_bucket.day2.bucket
}

output "bucket_arn" {
  description = "ARN of the Day 2 S3 bucket"
  value       = aws_s3_bucket.day2.arn
}

output "deployment_environment" {
  description = "Environment used for this deployment"
  value       = var.environment
}

output "name_prefix" {
  description = "Computed resource naming prefix"
  value       = local.name_prefix
}
