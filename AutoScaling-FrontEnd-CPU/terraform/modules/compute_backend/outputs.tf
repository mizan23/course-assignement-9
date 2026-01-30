output "instance_ids" {
  description = "List of backend instance IDs"
  value       = aws_instance.backend[*].id
}

output "private_ips" {
  description = "List of backend instance private IPs"
  value       = aws_instance.backend[*].private_ip
}

output "availability_zones" {
  description = "List of availability zones where instances are deployed"
  value       = aws_instance.backend[*].availability_zone
}
