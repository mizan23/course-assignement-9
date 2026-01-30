output "backend_alb_id" {
  description = "Backend ALB ID"
  value       = aws_lb.backend.id
}

output "backend_alb_arn" {
  description = "Backend ALB ARN"
  value       = aws_lb.backend.arn
}

output "backend_alb_dns" {
  description = "Backend ALB DNS name"
  value       = aws_lb.backend.dns_name
}

output "backend_tg_arn" {
  description = "Backend target group ARN"
  value       = aws_lb_target_group.backend.arn
}

output "frontend_alb_id" {
  description = "Frontend ALB ID"
  value       = aws_lb.frontend.id
}

output "frontend_alb_arn" {
  description = "Frontend ALB ARN"
  value       = aws_lb.frontend.arn
}

output "frontend_alb_dns" {
  description = "Frontend ALB DNS name"
  value       = aws_lb.frontend.dns_name
}

output "frontend_tg_arn" {
  description = "Frontend target group ARN"
  value       = aws_lb_target_group.frontend.arn
}
