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
  type = list(string)
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

variable "workers_per_core" {
  type = string
}

variable "web_concurrency" {
  type = string
}

variable "pghost" {
  type = string
}

variable "pgport" {
  type = string
}

variable "pgdatabase" {
  type = string
}

variable "pguser" {
  type = string
}

variable "pgpassword_arn" {
  type = string
}

variable "secret_key_arn" {
  type = string
}

variable "algorithm" {
  type = string
}

variable "access_token_expire_minutes" {
  type = string
}
