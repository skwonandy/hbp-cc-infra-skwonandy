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
