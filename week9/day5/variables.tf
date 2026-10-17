variable "bucket_suffix" {
  description = "Unique suffix for the temporary Day 5 bucket"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{8}$", var.bucket_suffix))
    error_message = "Provide exactly eight lowercase letters or digits."
  }
}
