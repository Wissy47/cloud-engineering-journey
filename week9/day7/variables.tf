variable "environment" {
  description = "Environment for the capstone infrastructure"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
  default     = "week9-capstone"
}

variable "vpc_cidr" {
  description = "CIDR block for the project VPC"
  type        = string
  default     = "10.97.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the project subnet"
  type        = string
  default     = "10.97.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}

variable "bucket_suffix" {
  description = "Unique eight-character suffix for the artifact bucket"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{8}$", var.bucket_suffix))
    error_message = "Provide exactly eight lowercase letters or digits."
  }
}