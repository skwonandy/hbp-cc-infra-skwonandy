variable "env" {
  type        = string
  description = "Environment name (dev, stg, prod)"
}

variable "project_name" {
  type        = string
  default     = "hbp-cc"
  description = "Project name prefix for resources"
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name (e.g. hbp-cc-dev-alb-xxx.elb.amazonaws.com)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for CloudFront distribution"
}

variable "aliases" {
  type        = list(string)
  default     = []
  description = "カスタムドメインの CNAME（例: api-dev.example.com）。空の場合は xxx.cloudfront.net のみ"
}

variable "acm_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM 証明書 ARN（us-east-1）。aliases を使う場合は必須"
}
