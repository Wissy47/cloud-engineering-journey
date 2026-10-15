output "vpc_id" {
  description = "ID of the Terraform-managed Day 3 VPC"
  value       = aws_vpc.day3.id
}

output "subnet_id" {
  description = "ID of the Terraform-managed Day 3 subnet"
  value       = aws_subnet.day3_subnet.id
}

output "subnet_vpc_id" {
  description = "VPC ID associated with the Day 3 subnet"
  value       = aws_subnet.day3_subnet.vpc_id
}
