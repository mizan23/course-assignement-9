variable "project_name" {
  description = "Project name for parameter path"
  type        = string
}

variable "db_host" {
  description = "Database host endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "backend_alb_url" {
  description = "Backend ALB URL"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
