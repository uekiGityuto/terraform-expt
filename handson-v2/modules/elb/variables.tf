variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(any)
}

variable "domain" {
  type = string
}

variable "acm_id" {
  type = string
}
