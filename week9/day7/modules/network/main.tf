resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  cidr_block        = var.subnet_cidr
  availability_zone = var.availability_zone

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-subnet"
    }
  )
}
