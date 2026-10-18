locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  artifact_bucket_name = "${var.project_name}-${var.environment}-artifacts-${var.bucket_suffix}"
}