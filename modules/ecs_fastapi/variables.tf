variable "env" {
  type = string
}

variable "service" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "https_listener_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(any)
}
