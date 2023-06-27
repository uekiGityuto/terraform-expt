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

variable "elb_security_group_id" {
  type = string
}

variable "subnet_ids" {
  type = list(any)
}

variable "cpu" {
  type = string
}

variable "memory" {
  type = string
}

variable "desired_count" {
  type = number
}
