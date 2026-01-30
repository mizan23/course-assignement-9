# Data sources for existing VPC infrastructure

data "aws_vpc" "devops" {
  filter {
    name   = "tag:Name"
    values = ["devops-vpc"]
  }
}

data "aws_subnet" "public_1a" {
  filter {
    name   = "tag:Name"
    values = ["devops-subnet-public1-ap-south-1a"]
  }
}

data "aws_subnet" "public_1b" {
  filter {
    name   = "tag:Name"
    values = ["devops-subnet-public2-ap-south-1b"]
  }
}

data "aws_subnet" "private_1a" {
  filter {
    name   = "tag:Name"
    values = ["devops-subnet-private1-ap-south-1a"]
  }
}

data "aws_subnet" "private_1b" {
  filter {
    name   = "tag:Name"
    values = ["devops-subnet-private2-ap-south-1b"]
  }
}

data "aws_internet_gateway" "devops" {
  filter {
    name   = "tag:Name"
    values = ["devops-igw"]
  }
}

data "aws_nat_gateway" "devops" {
  filter {
    name   = "tag:Name"
    values = ["devops-regional-nat"]
  }
}

data "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.devops.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  filter {
    name   = "tag:Name"
    values = ["devops-vpce-s3"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
