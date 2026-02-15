# CloudFront: フロント用（S3 オリジン、OAC）。alb_dns_name 指定時は /api/* を ALB へ転送（同一ドメイン）。

locals {
  name_prefix   = "${var.project_name}-${var.env}"
  api_origin_id = "api-alb"
  has_api       = var.alb_dns_name != ""
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  count = local.has_api ? 1 : 0

  name = "Managed-CachingDisabled"
}

# CORS + 認証ヘッダーを ALB に転送（/api/* 用）
resource "aws_cloudfront_origin_request_policy" "api_cors_auth" {
  count = local.has_api ? 1 : 0

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

# Origin Access Control（S3 は非公開のまま CloudFront のみアクセス許可）
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-frontend-oac"
  description                       = "OAC for ${local.name_prefix} frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# SPA ルーティング: 拡張子なしのパスを /index.html にリライト（viewer-request）。
# custom_error_response は Distribution 全体に適用され /api の 404/403 も上書きしてしまうため使わない。
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${local.name_prefix}-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "SPA: rewrite non-file paths to /index.html"
  publish = true

  code = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      // 拡張子があるパス（静的ファイル）はそのまま通す
      if (uri.includes('.')) {
        return request;
      }
      // 拡張子なし（SPA ルート）は /index.html にリライト
      request.uri = '/index.html';
      return request;
    }
  JS
}

# S3 バケットポリシー: CloudFront 経由の GetObject のみ許可
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${var.frontend_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_cloudfront_distribution.frontend]
}

# CloudFront ディストリビューション（フロント用）
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${local.name_prefix} frontend"
  price_class         = var.price_class
  aliases             = var.aliases

  origin {
    domain_name              = var.frontend_bucket_regional_domain_name
    origin_id                = "S3-${var.frontend_bucket_id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  dynamic "origin" {
    for_each = local.has_api ? [1] : []
    content {
      domain_name = var.alb_dns_name
      origin_id   = local.api_origin_id

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.has_api ? [1] : []
    content {
      path_pattern           = "/api/*"
      allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id        = local.api_origin_id
      cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled[0].id
      origin_request_policy_id = aws_cloudfront_origin_request_policy.api_cors_auth[0].id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.frontend_bucket_id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed CachingOptimized (no query/cookie forward)

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
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
