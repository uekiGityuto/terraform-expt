variable "name" {
  type    = string
  default = "myapp"
}

variable "azs" {
  default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "domain" {
  type    = string
  default = "waito-expt.com"
}

module "network" {
  source = "../../modules/network"
  name   = var.name
  azs    = var.azs
}

module "acm" {
  source = "../../modules/acm"
  name   = var.name
  domain = var.domain
}

module "elb" {
  source            = "../../modules/elb"
  name              = var.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  domain            = var.domain
  acm_id            = module.acm.acm_id
}

module "ecs_cluster" {
  source = "../../modules/ecs_cluster"
  name   = var.name
}

module "nginx" {
  source             = "../../modules/nginx"
  name               = var.name
  cluster_name       = module.ecs_cluster.cluster_name
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  https_listener_arn = module.elb.https_listener_arn
}
