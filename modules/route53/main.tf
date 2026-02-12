# Route53: 既存ホストゾーンを参照。A/AAAA や ACM 検証レコードは env または acm モジュールで作成する。
data "aws_route53_zone" "main" {
  zone_id = var.zone_id
}
