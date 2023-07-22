locals {
  env        = "stg"
  service    = "terraform-expt"
  domain     = "waito-expt.com"
  account_id = "428485887053"
  vpc_cidr   = "10.0.0.0/16"
  # 環境変数
  workers_per_core            = "3"
  web_concurrency             = "2"
  pgport                      = "5432"
  pgdatabase                  = "expt"
  pguser                      = "postgres"
  algorithm                   = "HS256"
  access_token_expire_minutes = "30"
}

module "network" {
  source               = "../../modules/network"
  env                  = local.env
  service              = local.service
  azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
  vpc_cidr             = local.vpc_cidr
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

module "rds" {
  source     = "../../modules/rds"
  env        = local.env
  service    = local.service
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  vpc_cidr   = local.vpc_cidr
  port       = local.pgport
  db_name    = local.pgdatabase
  user_name  = local.pguser
  password   = var.pgpassword
}

module "bastion" {
  source     = "../../modules/bastion"
  env        = local.env
  service    = local.service
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids
}

module "ecs" {
  source                = "../../modules/ecs"
  env                   = local.env
  service               = local.service
  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.private_subnet_ids
  https_listener_arn    = module.elb.https_listener_arn
  elb_security_group_id = module.elb.security_group_id
  cpu                   = "256"
  memory                = "512"
  desired_count         = 2
  account_id            = local.account_id
  # 環境変数
  workers_per_core            = local.workers_per_core
  web_concurrency             = local.web_concurrency
  pghost                      = module.rds.cluster_endpoint
  pgport                      = local.pgport
  pgdatabase                  = local.pgdatabase
  pguser                      = local.pguser
  algorithm                   = local.algorithm
  access_token_expire_minutes = local.access_token_expire_minutes
}
