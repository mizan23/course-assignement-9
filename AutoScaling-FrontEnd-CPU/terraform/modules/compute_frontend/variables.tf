variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for frontend instances (Golden AMI)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "List of subnet IDs for ASG"
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
  description = "Target group ARN for ASG"
  type        = string
}

variable "min_size" {
  description = "Minimum ASG size"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum ASG size"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired ASG capacity"
  type        = number
  default     = 2
}

variable "cpu_target" {
  description = "Target CPU utilization percentage"
  type        = number
  default     = 60
}

variable "warmup_time" {
  description = "Instance warmup time in seconds"
  type        = number
  default     = 60
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 300
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
