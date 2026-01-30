# Security Group for SSM VPC Endpoints
resource "aws_security_group" "ssm_endpoint" {
  name_prefix = "${var.project_name}-ssm-endpoint-"
  description = "Security group for SSM VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ssm-endpoint-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoint.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ssm-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoint.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ec2messages-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoint.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ssmmessages-endpoint"
    }
  )
}

# Security Group for Frontend ALB (Public)
resource "aws_security_group" "frontend_alb" {
  name_prefix = "${var.project_name}-frontend-alb-"
  description = "Security group for Frontend ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-frontend-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Frontend EC2 Instances
resource "aws_security_group" "frontend_ec2" {
  name_prefix = "${var.project_name}-frontend-ec2-"
  description = "Security group for Frontend EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from Frontend ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

  ingress {
    description = "HTTPS within VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-frontend-ec2-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Backend ALB (Internal)
resource "aws_security_group" "backend_alb" {
  name_prefix = "${var.project_name}-backend-alb-"
  description = "Security group for Backend Internal ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from Frontend EC2"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_ec2.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-backend-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Backend EC2 Instances
resource "aws_security_group" "backend_ec2" {
  name_prefix = "${var.project_name}-backend-ec2-"
  description = "Security group for Backend EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Port 3000 from Backend ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-backend-ec2-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_region" "current" {}
