variable "env" { type = string }
variable "project_name" {
  type    = string
  default = "hbp-cc"
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "frontend_bucket_id" {
  type        = string
  description = "S3 frontend bucket ID"
}
variable "frontend_bucket_arn" {
  type        = string
  description = "S3 frontend bucket ARN"
}
variable "frontend_bucket_regional_domain_name" {
  type        = string
  description = "S3 frontend bucket regional domain (e.g. bucket.s3.region.amazonaws.com)"
}

variable "price_class" {
  type        = string
  default     = "PriceClass_200"
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
}

variable "aliases" {
  type        = list(string)
  default     = []
  description = "カスタムドメインの CNAME（例: app-dev.example.com）。空の場合は xxx.cloudfront.net のみ"
}

variable "acm_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM 証明書 ARN（us-east-1）。aliases を使う場合は必須"
}

variable "alb_dns_name" {
  type        = string
  default     = ""
  description = "ALB DNS name for /api/* origin. Empty = frontend only (no API behavior)."
}

# count/for_each を plan 時に決めるため、計算値である alb_dns_name ではなくこちらで API オリジン有無を指定する
variable "enable_api_origin" {
  type        = bool
  default     = true
  description = "API オリジン（/api/*）を有効にするか。ALB がある環境では true。count の判定に使用するため plan 時に確定していること。"
}
