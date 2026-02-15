variable "env" {
  description = "Environment name (dev, stg, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "az_count" {
  description = "Number of AZs to use (RDS subnet group requires at least 2)"
  type        = number
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hbp-cc"
}

variable "github_org_repo" {
  description = "GitHub org/repo for OIDC (e.g. myorg/hbp-cc). Set to create deploy IAM role; leave default empty to skip."
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Create GitHub OIDC provider in this account. Set true only in one env (e.g. dev)."
  type        = bool
  default     = false
}

# RDS (postgres). パスワードは SSM のみ（-var での渡し方は廃止）。
variable "db_password_ssm_parameter_name" {
  description = "SSM Parameter Store path for RDS master password (SecureString). Empty = use /hbp-cc/<env>/rds-master-password per environment."
  type        = string
  default     = ""
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage_gb" {
  description = "RDS allocated storage (GB)"
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "RDS Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "RDS deletion protection (true for prod)"
  type        = bool
  default     = false
}

# ElastiCache (Redis)
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "elasticache_num_nodes" {
  description = "ElastiCache number of nodes"
  type        = number
  default     = 1
}

# ALB (optional HTTPS)
variable "alb_acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS. Empty = HTTP only."
  type        = string
  default     = ""
}

# ECS API
variable "ecs_task_cpu" {
  description = "ECS API task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "ECS API task memory (MB)"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "ECS API desired task count"
  type        = number
  default     = 1
}

# FastAPI _constants 用（未設定だと起動時クラッシュ）。dev ではプレースホルダーで起動可
variable "hbp_session_jwt_key" {
  type      = string
  default   = "dev-placeholder-session-jwt-key"
  sensitive = true
}
variable "hbp_user_invitation_jwt_key" {
  type      = string
  default   = "dev-placeholder-invitation-jwt-key"
  sensitive = true
}
variable "hbp_jwt_ext_key" {
  type      = string
  default   = "dev-placeholder-jwt-ext-key"
  sensitive = true
}
variable "hbp_onetime_jwt_key" {
  type      = string
  default   = "dev-placeholder-onetime-jwt-key"
  sensitive = true
}
variable "hbp_admin_jwt_key" {
  type      = string
  default   = "dev-placeholder-admin-jwt-key"
  sensitive = true
}
variable "totp_encryption_key" {
  type      = string
  default   = "dev-placeholder-totp-32bytes-long-enough!!"
  sensitive = true
}
variable "hbp_jwt_issuer" {
  type    = string
  default = "hbp-cc-dev"
}

# SES（両方空の場合は SES モジュールは作成しない）
variable "ses_domain" {
  type        = string
  default     = ""
  description = "SES 送信用ドメイン（検証済み）。空の場合は sender_email のみ使用可"
}
variable "ses_sender_email" {
  type        = string
  default     = ""
  description = "SES で検証する送信元メールアドレス（dev/sandbox ではこの 1 件を検証して送信に使用）"
}

# 既存 SES 参照（Terraform 管理外・ARN を直接構築して IAM ポリシーに渡す）
variable "ses_existing_domain" {
  type        = string
  default     = ""
  description = "既存 SES ドメイン名（例: xxxxx.com）。Terraform で作成せず参照のみ"
}
variable "ses_existing_region" {
  type        = string
  default     = ""
  description = "既存 SES のリージョン（例: us-west-2）。ses_existing_domain 指定時は必須"
}

# Terraform 実行用ロールを assume してよい IAM ユーザーまたはロールの ARN のリスト。空の場合はポリシーのみ作成しロールは作らない。
variable "terraform_runner_allow_assume_principal_arns" {
  description = "IAM user or role ARNs allowed to assume the Terraform runner role. Empty = policy only, no role."
  type        = list(string)
  default     = []
}

# カスタムドメイン（Route53 既存ゾーン + ACM + CloudFront aliases）。両方指定時のみ有効。
variable "base_domain" {
  description = "ベースドメイン（例: example.com）。指定時は app-<env>.<base_domain> / api-<env>.<base_domain> で配信"
  type        = string
  default     = ""
}
variable "route53_zone_id" {
  description = "既存 Route53 ホストゾーン ID。カスタムドメインを使う場合は必須"
  type        = string
  default     = ""
}
# ACM DNS 検証で既に Route53 に存在する CNAME の名前。指定したものは作成せず参照のみ（destroy で消えない）。
variable "acm_existing_validation_record_names" {
  type        = set(string)
  default     = []
  description = "既存の検証用 CNAME 名（FQDN）。指定したものは Terraform で作成しない"
}
