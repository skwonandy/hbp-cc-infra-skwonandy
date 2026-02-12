# dev 環境
env          = "dev"
aws_region   = "ap-northeast-1"
# RDS の DB サブネットグループは最低 2 AZ 必要なため 2 に設定
az_count     = 2
project_name = "hbp-cc"
vpc_cidr     = "10.1.0.0/16"

# GitHub Actions OIDC: デプロイ用 IAM ロールを作成。dev で OIDC プロバイダを 1 回だけ作成する想定
github_org_repo      = "skwonandy/hbp-cc-skwonandy"
create_oidc_provider = true

# RDS パスワードは SSM のみ（環境ごと /hbp-cc/<env>/rds-master-password に事前登録すること）

tags = {
  Environment = "dev"
  Project     = "hbp-cc"
  CostCenter  = "dev"
}

# SES: 送信元メールアドレスを指定すると SES モジュールが作成され、ECS タスクに送信権限が付与される。
# dev では SES サンドボックス利用を想定。指定したアドレスは AWS コンソールで検証済みにすること。
ses_sender_email = "dev-noreply@example.com"
