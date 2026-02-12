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
