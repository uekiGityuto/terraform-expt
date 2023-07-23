locals {
  base_db  = "/${var.env}/${var.service}/db"
  base_app = "/${var.env}/${var.service}/app"
}

# アクセスできるユーザを制限したい場合は、デフォルトのKMS（AWSマネージドキー）ではなく、カスタマー管理キー（CMK）を使って暗号化する（現状はアカウント内の全ユーザがアクセス可能）
# https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/sysman-paramstore-access.html#ps-kms-permissions

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
