variable "env" {
  type = string
}

variable "service" {
  type = string
}

variable "azs" {
  type    = list(string)
}

variable "vpc_cidr" {
  type    = string
}

variable "public_subnet_cidrs" {
  type    = list(string)
}

variable "private_subnet_cidrs" {
  type    = list(string)
}
