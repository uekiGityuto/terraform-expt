variable "env" {
  type = string
}

variable "service" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "port" {
  type    = string
  default = "5432"
}

variable "db_name" {
  type = string
}

variable "user_name" {
  type = string
}

variable "password" {
  type = string
}
