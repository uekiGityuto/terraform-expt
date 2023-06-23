variable "name" {
  type = string
}

variable "azs" {
  type    = list(any)
  default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

locals {
  public_subnets  = { for index, cidr in var.public_subnet_cidrs : index => { az = var.azs[index], cidr = cidr } }
  private_subnets = { for index, cidr in var.private_subnet_cidrs : index => { az = var.azs[index], cidr = cidr } }
}

# VPC
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.name
  }
}

# Public Subnet
resource "aws_subnet" "publics" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name = "${var.name}-public-${each.key}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

resource "aws_eip" "nat" {
  for_each = local.public_subnets

  domain = "vpc"

  tags = {
    Name = "${var.name}-natgw-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = local.public_subnets

  subnet_id     = aws_subnet.publics[each.key].id
  allocation_id = aws_eip.nat[each.key].id

  tags = {
    Name = "${var.name}-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.publics[each.key].id
  route_table_id = aws_route_table.public.id
}

# Private Subnet
resource "aws_subnet" "privates" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_route_table" "privates" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_route" "privates" {
  for_each = local.private_subnets

  destination_cidr_block = "0.0.0.0/0"

  route_table_id = aws_route_table.privates[each.key].id
  nat_gateway_id = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "privates" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.privates[each.key].id
  route_table_id = aws_route_table.privates[each.key].id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.publics : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.privates : s.id]
}
