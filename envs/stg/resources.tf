locals {
  env     = "stg"
  service = "terraform-expt"
  domain  = "waito-expt.com"
}

module "network" {
  source               = "../../modules/network"
  env                  = local.env
  service              = local.service
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
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

# module "nginx" {
#   source             = "../../modules/nginx"
#   env                = local.env
#   service            = local.service
#   vpc_id             = module.network.vpc_id
#   subnet_ids         = module.network.private_subnet_ids
#   https_listener_arn = module.elb.https_listener_arn
# }

module "ecs" {
  source             = "../../modules/ecs"
  env                = local.env
  service            = local.service
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  https_listener_arn = module.elb.https_listener_arn
  cpu                = "256"
  memory             = "512"
  desired_count      = 2
}
