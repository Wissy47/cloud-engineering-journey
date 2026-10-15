resource "aws_vpc" "day3" {
  cidr_block = var.vpc_cidr

  tags = {
    Name      = "${var.project_name}-week9-day3-vpc"
    ManagedBy = "Terraform"
    Lab       = "Week9Day3"
  }
}

resource "aws_subnet" "day3_subnet" {
  vpc_id            = aws_vpc.day3.id
  cidr_block        = var.subnet_cidr
  availability_zone = "us-east-1a"

  tags = {
    Name      = "${var.project_name}-week9-day3-subnet"
    ManagedBy = "Terraform"
    Lab       = "Week9Day3"
  }
}
