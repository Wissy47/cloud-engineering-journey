variable "bucket_name" {
  description = "Unique S3 bucket name"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters and use lowercase letters, numbers, dots, or hyphens."
  }
}

variable "tags" {
  description = "Tags applied to the S3 bucket"
  type        = map(string)
  default     = {}
}