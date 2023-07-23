locals {
  base_db  = "/${var.env}/${var.service}/db"
  base_app = "/${var.env}/${var.service}/app"
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${local.base_db}/password"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ssm_parameter" "app_secret_key" {
  name  = "${local.base_app}/secret_key"
  type  = "SecureString"
  value = var.app_secret_key
}
