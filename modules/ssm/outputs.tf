output "db_password_arn" {
  value = aws_ssm_parameter.db_password.arn
}

output "app_secret_key_arn" {
  value = aws_ssm_parameter.app_secret_key.arn
}
