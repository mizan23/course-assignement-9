# Data sources for existing VPC infrastructure

data "aws_vpc" "devops" {
  id = var.vpc_id
}

data "aws_subnet" "public_1a" {
  id = var.public_subnet_1a_id
}

data "aws_subnet" "public_1b" {
  id = var.public_subnet_1b_id
}

data "aws_subnet" "private_1a" {
  id = var.private_subnet_1a_id
}

data "aws_subnet" "private_1b" {
  id = var.private_subnet_1b_id
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
