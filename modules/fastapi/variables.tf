variable "env" {
  type = string
}

variable "service" {
  type = string
}

variable "ecr_url" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "https_listener_arn" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type = list(any)
}
