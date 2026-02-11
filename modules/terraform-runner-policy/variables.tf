variable "env" {
  description = "Environment name (dev, stg, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hbp-cc"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

# Terraform 実行用ロールを assume してよい IAM ユーザーまたはロールの ARN のリスト。空の場合はロールを作成しない（ポリシーのみ利用）。
variable "allow_assume_principal_arns" {
  description = "List of IAM user or role ARNs allowed to assume the Terraform runner role. Empty = do not create role (policy only)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for created resources"
  type        = map(string)
  default     = {}
}
