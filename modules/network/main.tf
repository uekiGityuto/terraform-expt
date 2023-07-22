locals {
  name            = "${var.env}-${var.service}"
  public_subnets  = { for index, cidr in var.public_subnet_cidrs : index => { az = var.azs[index], cidr = cidr } }
  private_subnets = { for index, cidr in var.private_subnet_cidrs : index => { az = var.azs[index], cidr = cidr } }
}

# VPC
#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "default" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.name
  }
}

# Public Subnet
resource "aws_subnet" "publics" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.default.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name}-public-${each.key}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = local.name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${local.name}-public"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.publics[each.key].id
  route_table_id = aws_route_table.public.id
}

# Private Subnet
resource "aws_subnet" "privates" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.default.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name = "${local.name}-private-${each.key}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${local.name}-private"
  }
}

resource "aws_route_table_association" "privates" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.privates[each.key].id
  route_table_id = aws_route_table.private.id
}

# VPC Endpoint

# ECSがECRからイメージを取得するときにS3へのアクセスも行われる（イメージレイヤーはS3に保存されているため）ので必要
# 参考(https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/userguide/vpc-endpoints.html#ecr-setting-up-s3-gateway)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.default.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

resource "aws_security_group" "vpc_endpoint" {
  name        = "${local.name}-vpc-endpoint"
  description = "${var.env} ${var.service} VPC endpoint security group"
  vpc_id      = aws_vpc.default.id

  tags = {
    Name = "${local.name}-vpc-endpoint"
  }
}

resource "aws_security_group_rule" "ingress" {
  security_group_id = aws_security_group.vpc_endpoint.id
  description       = "Allow HTTPS in VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.vpc_endpoint.id
  description       = "Allow HTTPS in VPC"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.default.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.privates : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.default.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.privates : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.default.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.privates : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.default.id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.privates : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
