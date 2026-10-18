output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the created subnet"
  value       = aws_subnet.public.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_cidr" {
  description = "CIDR block of the subnet"
  value       = aws_subnet.public.cidr_block
}
