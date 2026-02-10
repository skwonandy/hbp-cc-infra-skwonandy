output "alb_id" {
  description = "ALB ID"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ALB ARN (for CodeDeploy)"
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
  description = "HTTP listener ARN (CodeDeploy uses this to switch blue/green)"
  value       = aws_lb_listener.http.arn
}

output "listener_https_arn" {
  description = "HTTPS listener ARN when acm_certificate_arn is set (optional)"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "target_group_blue_arn" {
  description = "Blue target group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  description = "Green target group ARN"
  value       = aws_lb_target_group.green.arn
}

output "target_group_blue_name" {
  description = "Blue target group name (for CodeDeploy)"
  value       = aws_lb_target_group.blue.name
}

output "target_group_green_name" {
  description = "Green target group name (for CodeDeploy)"
  value       = aws_lb_target_group.green.name
}
