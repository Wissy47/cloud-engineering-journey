variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloudlab"
}

variable "bucket_suffix" {
  description = "Unique suffix for the temporary S3 bucket"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{8}$", var.bucket_suffix))
    error_message = "bucket_suffix must contain exactly 8 lowercase letters or digits."
  }
}
