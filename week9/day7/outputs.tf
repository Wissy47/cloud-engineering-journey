output "vpc_id" {
  description = "ID of the VPC created by the network module"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet created by the network module"
  value       = module.network.subnet_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.network.vpc_cidr
}

output "subnet_cidr" {
  description = "CIDR block of the subnet"
  value       = module.network.subnet_cidr
}
output "artifact_bucket_name" {
  description = "Name of the artifact bucket"
  value       = module.storage.bucket_id
}

output "artifact_bucket_arn" {
  description = "ARN of the artifact bucket"
  value       = module.storage.bucket_arn
}