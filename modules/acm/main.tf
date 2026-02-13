# ACM: CloudFront 用 TLS 証明書（us-east-1）。Route53 で DNS 検証。
# 呼び出し元で provider = aws.us_east_1 を渡すこと。
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-cloudfront"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 証明書の DNS 検証オプション（同一 resource_record_name は 1 件にまとめる）
locals {
  validation_options = {
    for k, v in {
      for dvo in aws_acm_certificate.main.domain_validation_options : dvo.resource_record_name => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }...
    } : k => v[0]
  }
  # 既存レコードとして扱う名前（比較用に正規化。末尾ドット除去）
  existing_normalized = toset([for n in var.existing_validation_record_names : trim(n, ".")])
  # 作成するレコードのみ（既存に含まれる名前はスキップ）
  validation_to_create = {
    for k, v in local.validation_options : k => v if !contains(local.existing_normalized, trim(k, "."))
  }
}

# DNS 検証用 CNAME（Route53）。既存レコード名は作成しない（参照のみ＝state に載せない）。
# 注意: for_each のキーは証明書の domain_validation_options に依存するため、証明書が未作成だと plan できない。
# 初回のみ: make apply-acm-cert で証明書を先に作成してから make plan / make apply を実行すること。
resource "aws_route53_record" "validation" {
  for_each = local.validation_to_create

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn
  validation_record_fqdns = concat(
    [for r in aws_route53_record.validation : r.fqdn],
    [for name in setintersection(local.existing_normalized, toset([for k in keys(local.validation_options) : trim(k, ".")])) : name]
  )
}
