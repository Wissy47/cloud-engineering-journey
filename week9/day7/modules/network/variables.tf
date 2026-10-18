variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "project_name" {
  description = "Project identifier for resource naming"
  type        = string
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}
