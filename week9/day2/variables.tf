variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "cloudlab"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition = contains(
      ["dev", "staging", "prod"],
      var.environment
    )

    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "bucket_suffix" {
  description = "Unique suffix for the S3 bucket"
  type        = string
}
