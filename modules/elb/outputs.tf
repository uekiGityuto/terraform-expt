output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}

output "security_group_id" {
  value = aws_security_group.default.id
}
