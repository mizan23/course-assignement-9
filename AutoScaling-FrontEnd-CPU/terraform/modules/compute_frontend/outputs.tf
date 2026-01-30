output "asg_id" {
  description = "Auto Scaling Group ID"
  value       = aws_autoscaling_group.frontend.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.frontend.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.frontend.arn
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.frontend.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.frontend.latest_version
}

output "scaling_policy_arn" {
  description = "CPU target tracking scaling policy ARN"
  value       = aws_autoscaling_policy.cpu_target_tracking.arn
}
