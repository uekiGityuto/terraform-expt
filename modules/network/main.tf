locals {
  name            = "${var.env}-${var.service}"
  public_subnets  = { for index, cidr in var.public_subnet_cidrs : index => { az = var.azs[index], cidr = cidr } }
  private_subnets = { for index, cidr in var.private_subnet_cidrs : index => { az = var.azs[index], cidr = cidr } }
}

# VPC
resource "aws_vpc" "default" {
  cidr_block = var.vpc_cidr

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

resource "aws_eip" "nat" {
  for_each = local.public_subnets

  domain = "vpc"

  tags = {
    Name = "${local.name}-natgw-${each.key}"
  }
}

# TODO: private linkの方が良いかも。そうすればEIPも不要なはず。
resource "aws_nat_gateway" "default" {
  for_each = local.public_subnets

  subnet_id     = aws_subnet.publics[each.key].id
  allocation_id = aws_eip.nat[each.key].id

  tags = {
    Name = "${local.name}-${each.key}"
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

resource "aws_route_table" "privates" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${local.name}-private-${each.key}"
  }
}

resource "aws_route" "privates" {
  for_each = local.private_subnets

  destination_cidr_block = "0.0.0.0/0"

  route_table_id = aws_route_table.privates[each.key].id
  nat_gateway_id = aws_nat_gateway.default[each.key].id
}

resource "aws_route_table_association" "privates" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.privates[each.key].id
  route_table_id = aws_route_table.privates[each.key].id
}
