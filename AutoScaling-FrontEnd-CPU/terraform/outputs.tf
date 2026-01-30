# Application URLs
output "application_url" {
  description = "Public URL to access the BMI application"
  value       = "http://${module.load_balancing.frontend_alb_dns}"
}

output "frontend_alb_dns" {
  description = "Frontend Application Load Balancer DNS name"
  value       = module.load_balancing.frontend_alb_dns
}

output "backend_alb_dns" {
  description = "Backend Internal Application Load Balancer DNS name"
  value       = module.load_balancing.backend_alb_dns
}

# Database Information
output "database_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.database.cluster_endpoint
  sensitive   = true
}

output "database_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.database.reader_endpoint
}

output "database_name" {
  description = "Database name"
  value       = var.db_name
}

# Security Group IDs
output "frontend_alb_sg_id" {
  description = "Frontend ALB security group ID"
  value       = module.network.frontend_alb_sg_id
}

output "frontend_ec2_sg_id" {
  description = "Frontend EC2 security group ID"
  value       = module.network.frontend_ec2_sg_id
}

output "backend_alb_sg_id" {
  description = "Backend ALB security group ID"
  value       = module.network.backend_alb_sg_id
}

output "backend_ec2_sg_id" {
  description = "Backend EC2 security group ID"
  value       = module.network.backend_ec2_sg_id
}

output "aurora_sg_id" {
  description = "Aurora database security group ID"
  value       = module.database.security_group_id
}

# IAM Resources
output "ec2_iam_role_name" {
  description = "IAM role name for EC2 instances"
  value       = module.iam.ec2_role_name
}

output "ec2_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  value       = module.iam.ec2_instance_profile_name
}

# Backend Instances
output "backend_instance_ids" {
  description = "List of backend EC2 instance IDs"
  value       = module.compute_backend.instance_ids
}

output "backend_private_ips" {
  description = "List of backend EC2 private IP addresses"
  value       = module.compute_backend.private_ips
}

# Frontend Auto Scaling
output "frontend_asg_name" {
  description = "Frontend Auto Scaling Group name"
  value       = module.compute_frontend.asg_name
}

output "frontend_launch_template_id" {
  description = "Frontend launch template ID"
  value       = module.compute_frontend.launch_template_id
}

# VPC Endpoints
output "ssm_vpc_endpoint_ids" {
  description = "SSM VPC endpoint IDs"
  value       = module.network.vpc_endpoint_ids
}

# Monitoring Commands
output "monitoring_commands" {
  description = "Useful AWS CLI commands for monitoring"
  value = <<-EOT
    # Monitor Frontend Auto Scaling Group
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${module.compute_frontend.asg_name} --region ${var.aws_region}
    
    # Monitor Frontend Target Health
    aws elbv2 describe-target-health --target-group-arn ${module.load_balancing.frontend_tg_arn} --region ${var.aws_region}
    
    # Monitor Backend Target Health
    aws elbv2 describe-target-health --target-group-arn ${module.load_balancing.backend_tg_arn} --region ${var.aws_region}
    
    # Connect to Backend Instance via SSM (replace INSTANCE_ID)
    aws ssm start-session --target INSTANCE_ID --region ${var.aws_region}
    
    # View ASG Activity
    aws autoscaling describe-scaling-activities --auto-scaling-group-name ${module.compute_frontend.asg_name} --max-records 10 --region ${var.aws_region}
  EOT
}

# Quick Start Guide
output "quick_start_guide" {
  description = "Quick start guide for accessing and testing the application"
  value = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║          BMI Auto-Scaling Application - Deployed! 🎉           ║
    ╚════════════════════════════════════════════════════════════════╝
    
    📱 Application URL:
       http://${module.load_balancing.frontend_alb_dns}
    
    🔍 Monitoring:
       • Frontend ASG: ${module.compute_frontend.asg_name}
       • Backend Instances: ${var.backend_instance_count} fixed instances
       • Database: Aurora Serverless v2 (${var.aurora_min_capacity}-${var.aurora_max_capacity} ACU)
    
    📊 Load Testing (Demonstrate Auto-Scaling):
       cd ../load-test
       ./quick-test.sh http://${module.load_balancing.frontend_alb_dns}
    
    🔐 SSH Access (via SSM):
       aws ssm start-session --target <instance-id> --region ${var.aws_region}
    
    ⚠️  IMPORTANT - Cleanup After Demo:
       terraform destroy -auto-approve
    
    💰 Current Cost: ~$0.20-$0.40/hour
  EOT
}
