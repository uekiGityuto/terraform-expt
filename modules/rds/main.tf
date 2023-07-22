locals {
  name = "${var.env}-${var.service}"
}

resource "aws_security_group" "default" {
  name        = "${local.name}-rds"
  description = "${var.env} ${var.service} rds security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name}-rds"
  }
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.default.id
  description       = "Allow all to anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "postgres" {
  security_group_id = aws_security_group.default.id
  description       = "Allow PostgreSQL from VPC"
  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_db_subnet_group" "default" {
  name        = local.name
  description = "${var.env} ${var.service} rds subnet group"
  subnet_ids  = var.subnet_ids
}

resource "aws_rds_cluster_parameter_group" "default" {
  name        = "${local.name}-cluster-parameter-group"
  family      = "aurora-postgresql15"
  description = "${var.env} ${var.service} cluster parameter group"
  parameter {
    name  = "timezone"
    value = "Asia/Tokyo"
  }
}

# TODO: 暗号化すべき
# tfsec:ignore:aws-rds-encrypt-cluster-storage-data
resource "aws_rds_cluster" "default" {
  cluster_identifier              = local.name
  db_subnet_group_name            = aws_db_subnet_group.default.name
  vpc_security_group_ids          = [aws_security_group.default.id]
  backup_retention_period         = 7
  preferred_backup_window         = "15:00-15:30"
  preferred_maintenance_window    = "sun:16:00-sun:16:30"
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.default.name

  engine         = "aurora-postgresql"
  engine_version = "15.3"
  port           = var.port

  database_name   = var.db_name
  master_username = var.user_name
  master_password = var.password

  # 実際はfalseの方が良いが検証用にtrueにしている
  skip_final_snapshot = true
  apply_immediately   = true
}

resource "aws_db_parameter_group" "default" {
  name        = "${local.name}-db-parameter-group"
  family      = "aurora-postgresql15"
  description = "${var.env} ${var.service} db parameter group"
}

# TODO: 複数インスタンス作成できるようにする
#tfsec:ignore:aws-rds-enable-performance-insights-encryption
resource "aws_rds_cluster_instance" "default" {
  identifier                   = local.name
  cluster_identifier           = aws_rds_cluster.default.id
  db_subnet_group_name         = aws_db_subnet_group.default.name
  engine                       = aws_rds_cluster.default.engine
  engine_version               = aws_rds_cluster.default.engine_version
  instance_class               = "db.t4g.medium"
  db_parameter_group_name      = aws_db_parameter_group.default.name
  performance_insights_enabled = true
}
