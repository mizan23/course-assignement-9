output "parameter_arns" {
  description = "Map of parameter ARNs"
  value = {
    db_host         = aws_ssm_parameter.db_host.arn
    db_name         = aws_ssm_parameter.db_name.arn
    db_user         = aws_ssm_parameter.db_user.arn
    db_password     = aws_ssm_parameter.db_password.arn
    backend_alb_url = aws_ssm_parameter.backend_alb_url.arn
  }
}

output "parameter_names" {
  description = "Map of parameter names"
  value = {
    db_host         = aws_ssm_parameter.db_host.name
    db_name         = aws_ssm_parameter.db_name.name
    db_user         = aws_ssm_parameter.db_user.name
    db_password     = aws_ssm_parameter.db_password.name
    backend_alb_url = aws_ssm_parameter.backend_alb_url.name
  }
}
