# IAM で ses:SendEmail / ses:SendRawEmail を許可する際のリソース ARN 一覧
output "identity_arns" {
  description = "SES identity ARNs (for ECS task role policy)"
  value = concat(
    var.domain != "" ? [aws_ses_domain_identity.main[0].arn] : [],
    var.sender_email != "" ? [aws_ses_email_identity.sender[0].arn] : []
  )
}

output "domain_identity_arn" {
  description = "Domain identity ARN (empty string if not used)"
  value       = var.domain != "" ? aws_ses_domain_identity.main[0].arn : ""
}

output "email_identity_arn" {
  description = "Email identity ARN (empty string if not used)"
  value       = var.sender_email != "" ? aws_ses_email_identity.sender[0].arn : ""
}

# ドメイン指定時: DKIM 用 CNAME レコード（Route53 等で設定する値）
output "dkim_tokens" {
  description = "DKIM tokens for domain (add CNAME records in DNS)"
  value       = var.domain != "" ? aws_ses_domain_dkim.main[0].dkim_tokens : []
}
