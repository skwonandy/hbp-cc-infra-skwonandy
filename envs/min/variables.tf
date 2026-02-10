variable "env" {
  description = "Environment name (min, dev, stg, prod). min = 最小スペックでAWSに全てデプロイ"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "az_count" {
  description = "Number of AZs to use (1 for min to reduce cost)"
  type        = number
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# VPC
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
  description = "Create GitHub OIDC provider in this account. Set true only in one env (e.g. min)."
  type        = bool
  default     = false
}

# RDS (postgres); do not set db_password in tfvars — use TF_VAR_db_password or -var
variable "db_password" {
  description = "RDS master password (pass via TF_VAR_db_password or -var)"
  type        = string
  sensitive   = true
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

# リスナー default で転送する TG。TaskSet が green のときは "green" にしないと CodeDeploy が「TaskSet is behind prod listener」で失敗する。デプロイが安定したら "blue" に戻す
variable "alb_listener_default_target_group" {
  description = "Listener default target group: blue or green (must match primary TaskSet's TG)"
  type        = string
  default     = "blue"
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

# FastAPI _constants 用（未設定だと起動時クラッシュ）。min ではプレースホルダーで起動可
variable "hbp_session_jwt_key" {
  type      = string
  default   = "min-placeholder-session-jwt-key"
  sensitive = true
}
variable "hbp_user_invitation_jwt_key" {
  type      = string
  default   = "min-placeholder-invitation-jwt-key"
  sensitive = true
}
variable "hbp_jwt_ext_key" {
  type      = string
  default   = "min-placeholder-jwt-ext-key"
  sensitive = true
}
variable "hbp_onetime_jwt_key" {
  type      = string
  default   = "min-placeholder-onetime-jwt-key"
  sensitive = true
}
variable "hbp_admin_jwt_key" {
  type      = string
  default   = "min-placeholder-admin-jwt-key"
  sensitive = true
}
variable "totp_encryption_key" {
  type      = string
  default   = "min-placeholder-totp-32bytes-long-enough!!"
  sensitive = true
}
variable "hbp_jwt_issuer" {
  type    = string
  default = "hbp-cc-min"
}
