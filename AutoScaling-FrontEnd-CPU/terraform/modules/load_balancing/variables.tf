variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for frontend ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for backend ALB"
  type        = list(string)
}

variable "frontend_alb_sg_id" {
  description = "Security group ID for frontend ALB"
  type        = string
}

variable "backend_alb_sg_id" {
  description = "Security group ID for backend ALB"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
