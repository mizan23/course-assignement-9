variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_count" {
  description = "Number of backend instances to create"
  type        = number
  default     = 2
}

variable "ami_id" {
  description = "AMI ID for backend instances (Golden AMI)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "List of subnet IDs for instances"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for instances"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for instance registration"
  type        = string
}

variable "github_repo_url" {
  description = "GitHub repository URL for deployment scripts"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
