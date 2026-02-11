variable "env" { type = string }
variable "project_name" { type = string; default = "hbp-cc" }
variable "tags" { type = map(string); default = {} }

# 少なくともどちらか一方を指定すること。ドメインは本番向け、sender_email は dev/sandbox 向け
variable "domain" {
  type        = string
  default     = ""
  description = "SES で送信に使うドメイン（検証済みドメイン ID）。空の場合は email のみ使用"
}
variable "sender_email" {
  type        = string
  default     = ""
  description = "検証する送信元メールアドレス（SES サンドボックスではこのアドレスから送信）。空の場合は domain のみ使用"

  validation {
    condition     = var.domain != "" || var.sender_email != ""
    error_message = "SES モジュールでは domain または sender_email の少なくとも一方を指定してください。"
  }
}
