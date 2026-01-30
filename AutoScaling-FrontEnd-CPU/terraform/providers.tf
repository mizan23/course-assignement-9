terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
  default_tags {
    tags = {
      Project     = "BMI-AutoScaling"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    }
  }
}
