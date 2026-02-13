# CloudFront: API 用（ALB オリジン）。HTTPS 配信、キャッシュ無効。

locals {
  name_prefix = "${var.project_name}-${var.env}"
  origin_id    = "api-alb"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# CORS + 認証ヘッダーをオリジン（ALB）に転送するカスタムポリシー
# CORS-S3Origin は x-authorization / x-admin-authorization を転送しないため 401 になる。
# カスタムポリシーで CORS 用ヘッダー + 認証ヘッダーを明示的に転送する。
resource "aws_cloudfront_origin_request_policy" "api_cors_auth" {
  name    = "${local.name_prefix}-api-cors-auth"
  comment = "CORS + x-authorization, x-admin-authorization for API"

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Origin",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "x-authorization",
        "x-admin-authorization"
      ]
    }
  }

  cookies_config {
    cookie_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "none"
  }
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
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_cors_auth.id
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
