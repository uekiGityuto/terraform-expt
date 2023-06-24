locals {
  env     = "stg"
  service = "terraform-expt"
  domain  = "waito-expt.com"
  azs     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

module "network" {
  source  = "../../modules/network"
  env     = local.env
  service = local.service
  azs     = local.azs
}

module "acm" {
  source = "../../modules/acm"
  domain = local.domain
}

module "elb" {
  source            = "../../modules/elb"
  env               = local.env
  service           = local.service
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  domain            = local.domain
  acm_id            = module.acm.acm_id
}

module "ecs_cluster" {
  source  = "../../modules/ecs_cluster"
  env     = local.env
  service = local.service
}

module "nginx" {
  source             = "../../modules/nginx"
  env                = local.env
  service            = local.service
  cluster_name       = module.ecs_cluster.cluster_name
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  https_listener_arn = module.elb.https_listener_arn
}
