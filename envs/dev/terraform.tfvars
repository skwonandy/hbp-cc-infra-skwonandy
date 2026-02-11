# dev 環境（旧 min 相当のフルスタック）
env          = "dev"
aws_region   = "ap-northeast-1"
# RDS の DB サブネットグループは最低 2 AZ 必要なため 2 に設定
az_count     = 2
project_name = "hbp-cc"
vpc_cidr     = "10.1.0.0/16"

# GitHub Actions OIDC: デプロイ用 IAM ロールを作成。dev で OIDC プロバイダを 1 回だけ作成する想定
github_org_repo      = "skwonandy/hbp-cc-skwonandy"
create_oidc_provider = true

# db_password は tfvars に書かず、TF_VAR_db_password または -var で渡すこと

tags = {
  Environment = "dev"
  Project     = "hbp-cc"
  CostCenter  = "dev"
}
