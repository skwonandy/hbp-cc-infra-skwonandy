output "certificate_arn" {
  description = "ACM 証明書 ARN（CloudFront の viewer_certificate に指定）"
  value       = aws_acm_certificate.main.arn
}
