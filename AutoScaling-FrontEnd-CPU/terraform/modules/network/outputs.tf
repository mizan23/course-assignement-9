output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint IDs"
  value = {
    ssm         = aws_vpc_endpoint.ssm.id
    ec2messages = aws_vpc_endpoint.ec2messages.id
    ssmmessages = aws_vpc_endpoint.ssmmessages.id
  }
}

output "ssm_endpoint_sg_id" {
  description = "SSM VPC endpoint security group ID"
  value       = aws_security_group.ssm_endpoint.id
}

output "frontend_alb_sg_id" {
  description = "Frontend ALB security group ID"
  value       = aws_security_group.frontend_alb.id
}

output "frontend_ec2_sg_id" {
  description = "Frontend EC2 security group ID"
  value       = aws_security_group.frontend_ec2.id
}

output "backend_alb_sg_id" {
  description = "Backend ALB security group ID"
  value       = aws_security_group.backend_alb.id
}

output "backend_ec2_sg_id" {
  description = "Backend EC2 security group ID"
  value       = aws_security_group.backend_ec2.id
}
