variable "project_name" {
  description = "Project name used for resource identification"
  type        = string
  default     = "cloudlab"
}

variable "vpc_cidr" {
  description = "CIDR block for the temporary Day 3 VPC"
  type        = string
  default     = "10.90.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the temporary Day 3 subnet"
  type        = string
  default     = "10.90.1.0/24"
}
