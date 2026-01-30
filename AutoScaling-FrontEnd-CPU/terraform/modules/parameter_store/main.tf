# SSM Parameter for Database Host
resource "aws_ssm_parameter" "db_host" {
  name        = "/${var.project_name}-app/db-host"
  description = "Aurora cluster endpoint"
  type        = "String"
  value       = var.db_host
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-db-host"
    }
  )
}

# SSM Parameter for Database Name
resource "aws_ssm_parameter" "db_name" {
  name        = "/${var.project_name}-app/db-name"
  description = "Database name"
  type        = "String"
  value       = var.db_name
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-db-name"
    }
  )
}

# SSM Parameter for Database User
resource "aws_ssm_parameter" "db_user" {
  name        = "/${var.project_name}-app/db-user"
  description = "Database username"
  type        = "String"
  value       = var.db_user
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-db-user"
    }
  )
}

# SSM Parameter for Database Password (SecureString)
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}-app/db-password"
  description = "Database password"
  type        = "SecureString"
  value       = var.db_password
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-db-password"
    }
  )
}

# SSM Parameter for Backend ALB URL
resource "aws_ssm_parameter" "backend_alb_url" {
  name        = "/${var.project_name}-app/backend-alb-url"
  description = "Backend ALB URL"
  type        = "String"
  value       = var.backend_alb_url
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-backend-alb-url"
    }
  )
}
