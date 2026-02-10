# 最小スペックで AWS に全てデプロイする環境（dev より低スペック）
env         = "min"
aws_region  = "ap-northeast-1"
# RDS の DB サブネットグループは最低 2 AZ 必要なため 2 に設定
az_count    = 2
project_name = "hbp-cc"
vpc_cidr    = "10.0.0.0/16"

# GitHub Actions OIDC: デプロイ用 IAM ロールを作成。min で OIDC プロバイダを 1 回だけ作成する想定
github_org_repo      = "skwonandy/hbp-cc-skwonandy"
create_oidc_provider = true

tags = {
  Environment = "min"
  Project     = "hbp-cc"
  CostCenter  = "min"
}
