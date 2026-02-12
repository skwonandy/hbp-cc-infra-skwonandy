# CloudFront: API 用（ALB オリジン）。HTTPS 配信、キャッシュ無効。

locals {
  name_prefix = "${var.project_name}-${var.env}"
  origin_id    = "api-alb"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# CORS のためブラウザの Origin / プリフライト用ヘッダーをオリジン（ALB）に転送する（ID でマネージドポリシーを参照）
# CORS-CustomOrigin: Origin のみ。プリフライト対応のため CORS-S3Origin（Origin + Access-Control-Request-*）を使用
data "aws_cloudfront_origin_request_policy" "cors_custom" {
  id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed CORS-S3Origin（カスタムオリジンでも利用可）
}

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${local.name_prefix} api"
  price_class     = "PriceClass_200"
  aliases         = var.aliases

  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = local.origin_id
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_custom.id
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == ""
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = var.tags
}
