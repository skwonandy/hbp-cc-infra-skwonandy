output "zone_id" {
  description = "Route53 ホストゾーン ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "name" {
  description = "ホストゾーンのドメイン名"
  value       = data.aws_route53_zone.main.name
}
