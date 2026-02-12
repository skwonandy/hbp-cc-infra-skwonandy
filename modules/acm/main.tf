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

# DNS 検証用 CNAME（Route53）。検証が完了すると証明書が ISSUED になる。
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
