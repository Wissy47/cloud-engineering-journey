output "bucket_name" {
  description = "Name of the bucket created through the child module"
  value       = module.storage.bucket_id
}

output "bucket_arn" {
  description = "ARN of the bucket created through the child module"
  value       = module.storage.bucket_arn
}
output "backup_bucket_name" {
  description = "Name of the bucket created by the backups module"
  value       = module.backups.bucket_id
}

output "backup_bucket_arn" {
  description = "ARN of the bucket created by the backups module"
  value       = module.backups.bucket_arn
}
