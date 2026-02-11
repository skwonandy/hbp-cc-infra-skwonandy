# SES: 送信ドメイン・メールアドレス検証。AWS_SES_REGION と連携。
# domain または sender_email の少なくとも一方を指定すること。

# ドメイン ID（任意）
resource "aws_ses_domain_identity" "main" {
  count  = var.domain != "" ? 1 : 0
  domain = var.domain
}

# ドメインの DKIM（任意・ドメイン指定時）
resource "aws_ses_domain_dkim" "main" {
  count  = var.domain != "" ? 1 : 0
  domain = aws_ses_domain_identity.main[0].domain
}

# 送信元メールアドレス検証（任意・dev/sandbox で 1 アドレス検証する場合）
resource "aws_ses_email_identity" "sender" {
  count  = var.sender_email != "" ? 1 : 0
  email  = var.sender_email
}
