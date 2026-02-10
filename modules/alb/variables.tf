variable "env" { type = string }
variable "project_name" {
  type    = string
  default = "hbp-cc"
}
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "target_port" {
  type        = number
  default     = 7788
  description = "Target group port (FastAPI default 7788)"
}

variable "health_check_path" {
  type        = string
  default     = "/api/healthcheck/"
  description = "Health check path for target group (FastAPI healthcheck endpoint)"
}

variable "health_check_interval" {
  type        = number
  default     = 30
  description = "Health check interval in seconds"
}

variable "health_check_timeout" {
  type        = number
  default     = 5
  description = "Health check timeout in seconds"
}

variable "health_check_unhealthy_threshold" {
  type        = number
  default     = 6
  description = "Consecutive health check failures before target is unhealthy (app may take time to start)"
}

variable "acm_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for HTTPS listener. Empty = HTTP only."
}

# リスナー default で転送するターゲットグループ（blue または green）。primary が green のときは "green" にすると CodeDeploy エラーを解消できる
variable "listener_default_target_group" {
  type        = string
  default     = "blue"
  description = "Which target group the listener default forwards to: blue or green."
}
