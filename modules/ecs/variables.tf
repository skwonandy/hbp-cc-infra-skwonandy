variable "env" { type = string }
variable "project_name" {
  type    = string
  default = "hbp-cc"
}
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "internal_security_group_id" {
  type        = string
  description = "VPC internal SG (for RDS/Redis access)"
}
variable "alb_security_group_id" {
  type        = string
  description = "ALB SG (for ECS ingress from ALB)"
}
variable "target_group_blue_arn" { type = string }
variable "target_group_green_arn" { type = string }
variable "target_group_blue_name" { type = string }
variable "target_group_green_name" { type = string }
variable "alb_listener_arn" {
  type        = string
  description = "ALB listener ARN (CodeDeploy switches traffic)"
}

variable "ecr_api_repository_url" { type = string }
variable "db_host" { type = string }
variable "db_name" { type = string }
variable "db_user" { type = string }
variable "db_password_plain" {
  type        = string
  default     = null
  sensitive   = true
  description = "DB password for task env (use when db_password_secret_arn is empty)"
}
variable "db_password_secret_arn" {
  type        = string
  default     = ""
  description = "Secrets Manager ARN for DB_PASSWORD (preferred over db_password_plain)"
}
variable "redis_host" { type = string }
variable "s3_app_bucket" { type = string }
variable "aws_region" { type = string }

# FastAPI 起動に必須（未設定だと KeyError / 起動失敗）
variable "service_url" {
  type        = string
  description = "フロントエンドの URL (SERVICE_URL: CORS ALLOWED_ORIGINS・メールリンクのベース)。service_url_ssm_arn 未指定時のみ environment に使用"
}
variable "service_url_ssm_arn" {
  type        = string
  default     = ""
  description = "SSM パラメータ ARN。指定時は SERVICE_URL を AWS (SSM) から取得して環境変数にセット（secrets で注入）"
}
variable "app_env" {
  type        = string
  default     = "dev"
  description = "ENV (アプリの _types.env.Env: local, dev, stg, prod). min では dev を指定"
}
variable "db_pool_size" {
  type        = number
  default     = 5
  description = "DB_POOL_SIZE"
}
variable "db_host_replications" {
  type        = string
  default     = "[]"
  description = "DB_HOST_REPLICATIONS (Python の list として eval される、例: '[]')"
}
variable "api_extra_environment" {
  type = list(object({ name = string, value = string }))
  default = []
  description = "追加の環境変数 (JWT 系など)。{ name, value } のリスト"
}

variable "sentry_dsn" {
  type        = string
  default     = ""
  description = "Sentry DSN (空文字列の場合は Sentry 無効)"
}

variable "container_port" {
  type    = number
  default = 7788
}
variable "task_cpu" {
  type    = number
  default = 256
}
variable "task_memory" {
  type    = number
  default = 512
}
variable "desired_count" {
  type    = number
  default = 1
}
variable "log_retention_days" {
  type    = number
  default = 7
}
variable "enable_execute_command" {
  type    = bool
  default = false
}
variable "codedeploy_deployment_config_name" {
  type    = string
  default = "CodeDeployDefault.ECSAllAtOnce"
}
variable "blue_termination_wait_minutes" {
  type    = number
  default = 5
}
variable "health_check_grace_period_seconds" {
  type        = number
  default     = 120
  description = "Grace period before ALB health checks can mark the task unhealthy (app startup time)"
}
