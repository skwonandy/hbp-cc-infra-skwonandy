terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.env
      Project     = var.project_name
    })
  }
}

# Terraform 実行時の認証情報確認用（plan/apply 時にどの identity か分かる）
data "aws_caller_identity" "current" {}

# RDS マスターパスワード: SSM から取得（環境ごとに /hbp-cc/<env>/rds-master-password。事前に SSM へ登録すること）
locals {
  rds_password_ssm_path = var.db_password_ssm_parameter_name != "" ? var.db_password_ssm_parameter_name : "/hbp-cc/${var.env}/rds-master-password"
}

data "aws_ssm_parameter" "rds_password" {
  name            = local.rds_password_ssm_path
  with_decryption = true
}

locals {
  rds_password = data.aws_ssm_parameter.rds_password.value
}

check "rds_password_set" {
  assert {
    condition     = length(local.rds_password) >= 8 && length(local.rds_password) <= 128
    error_message = "SSM parameter ${local.rds_password_ssm_path} must be 8-128 characters (RDS requirement)."
  }
}

module "vpc" {
  source = "../../modules/vpc"

  env          = var.env
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  project_name = var.project_name
  tags         = var.tags
}

# RDS: allowed_security_group_ids = VPC internal SG until ECS exists; then pass ECS SG
module "rds" {
  source = "../../modules/rds"

  env                      = var.env
  project_name             = var.project_name
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.vpc.internal_security_group_id]
  instance_class           = var.rds_instance_class
  allocated_storage_gb     = var.rds_allocated_storage_gb
  multi_az                 = var.rds_multi_az
  deletion_protection     = var.rds_deletion_protection
  tags                     = var.tags
  db_password              = local.rds_password
}

module "elasticache" {
  source = "../../modules/elasticache"

  env                        = var.env
  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  allowed_security_group_ids  = [module.vpc.internal_security_group_id]
  node_type                  = var.elasticache_node_type
  num_cache_nodes            = var.elasticache_num_nodes
  tags                       = var.tags
}

module "s3" {
  source = "../../modules/s3"

  env          = var.env
  project_name = var.project_name
  tags         = var.tags
}

module "cicd" {
  source = "../../modules/cicd"

  env                      = var.env
  project_name             = var.project_name
  tags                     = var.tags
  create_worker_repository = false # dev では worker をデプロイしない
  github_org_repo          = var.github_org_repo
  create_oidc_provider     = var.create_oidc_provider
}

module "alb" {
  source = "../../modules/alb"

  env                           = var.env
  project_name                  = var.project_name
  vpc_id                        = module.vpc.vpc_id
  public_subnet_ids             = module.vpc.public_subnet_ids
  tags                          = var.tags
  acm_certificate_arn            = var.alb_acm_certificate_arn
  listener_default_target_group  = var.alb_listener_default_target_group
}

module "ecs" {
  source = "../../modules/ecs"

  env                          = var.env
  project_name                 = var.project_name
  vpc_id                       = module.vpc.vpc_id
  private_subnet_ids           = module.vpc.private_subnet_ids
  internal_security_group_id   = module.vpc.internal_security_group_id
  alb_security_group_id        = module.alb.alb_security_group_id
  target_group_blue_arn        = module.alb.target_group_blue_arn
  target_group_green_arn       = module.alb.target_group_green_arn
  target_group_blue_name       = module.alb.target_group_blue_name
  target_group_green_name      = module.alb.target_group_green_name
  alb_listener_arn             = module.alb.listener_arn
  ecr_api_repository_url       = module.cicd.ecr_api_url
  db_host                      = module.rds.db_instance_address
  db_host_replications         = "[\"${module.rds.db_instance_address}\"]"
  db_name                      = "main"
  db_user                      = "postgres"
  db_password_plain            = local.rds_password
  db_password_secret_arn       = ""
  redis_host                   = module.elasticache.redis_host
  s3_app_bucket                = module.s3.app_bucket_id
  aws_region                   = var.aws_region
  service_url                  = module.cloudfront.cloudfront_url
  use_service_url_ssm          = true
  service_url_ssm_arn          = aws_ssm_parameter.service_url.arn
  app_env                      = "dev"
  sentry_dsn                   = ""
  attach_ses_policy            = true
  ses_identity_arns            = try(module.ses[0].identity_arns, [])
  api_extra_environment        = [
    { name = "HBP_SESSION_JWT_KEY", value = var.hbp_session_jwt_key },
    { name = "HBP_USER_INVITATION_JWT_KEY", value = var.hbp_user_invitation_jwt_key },
    { name = "HBP_JWT_EXT_KEY", value = var.hbp_jwt_ext_key },
    { name = "HBP_ONETIME_JWT_KEY", value = var.hbp_onetime_jwt_key },
    { name = "HBP_ADMIN_JWT_KEY", value = var.hbp_admin_jwt_key },
    { name = "TOTP_ENCRYPTION_KEY", value = var.totp_encryption_key },
    { name = "HBP_JWT_ISSUER", value = var.hbp_jwt_issuer },
  ]
  task_cpu                     = var.ecs_task_cpu
  task_memory                  = var.ecs_task_memory
  desired_count                = var.ecs_desired_count
  blue_termination_wait_minutes = 1 # 開発環境: 高速デプロイのため1分に短縮
  tags                         = var.tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  env                                 = var.env
  project_name                        = var.project_name
  frontend_bucket_id                  = module.s3.frontend_bucket_id
  frontend_bucket_arn                 = module.s3.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.s3.frontend_bucket_regional_domain_name
  tags                                = var.tags
}

# SES: domain または ses_sender_email のいずれかを指定した場合のみ作成
module "ses" {
  source = "../../modules/ses"
  count  = var.ses_domain != "" || var.ses_sender_email != "" ? 1 : 0

  env          = var.env
  project_name = var.project_name
  domain       = var.ses_domain
  sender_email = var.ses_sender_email
  tags         = var.tags
}

# フロントエンドビルド時に API のベース URL を参照するため（GitHub Actions が SSM から取得）
resource "aws_ssm_parameter" "api_base_url" {
  name        = "/hbp-cc/${var.env}/api-base-url"
  description = "API base URL for frontend build (e.g. ALB URL + /api)"
  type        = "String"
  value       = "http://${module.alb.alb_dns_name}/api"
  overwrite   = true
}

# バックエンドの SERVICE_URL（CORS / ALLOWED_ORIGINS・メールリンクのベース）。フロントエンドの URL。ECS タスクは SSM から取得して環境変数にセット
resource "aws_ssm_parameter" "service_url" {
  name        = "/hbp-cc/${var.env}/service-url"
  description = "Frontend URL (SERVICE_URL, ALLOWED_ORIGINS, mail links)"
  type        = "String"
  value       = module.cloudfront.cloudfront_url
  overwrite   = true
}

# dev では Batch は不要（ジョブ実行は行わない）
# module "batch" { ... }
