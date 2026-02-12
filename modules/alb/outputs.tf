output "alb_id" {
  description = "ALB ID"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID (Route53 alias)"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "ALB security group ID (for ECS SG ingress)"
  value       = aws_security_group.alb.id
}

output "listener_arn" {
  description = "HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

output "listener_https_arn" {
  description = "HTTPS listener ARN when acm_certificate_arn is set (optional)"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "target_group_arn" {
  description = "API target group ARN (for ECS service)"
  value       = aws_lb_target_group.api.arn
}

output "target_group_name" {
  description = "API target group name"
  value       = aws_lb_target_group.api.name
}
