# dev 環境
env          = "dev"
aws_region   = "ap-northeast-1"
# RDS の DB サブネットグループは最低 2 AZ 必要なため 2 に設定
az_count     = 2
project_name = "hbp-cc"
vpc_cidr     = "10.1.0.0/16"

# GitHub Actions OIDC: デプロイ用 IAM ロールを作成。dev で OIDC プロバイダを 1 回だけ作成する想定
github_org_repo      = "skwonandy/hbp-cc-skwonandy"
# OIDC Provider は既存（他で管理）のため data source で参照のみ
create_oidc_provider = false

# RDS パスワードは SSM のみ（環境ごと /hbp-cc/<env>/rds-master-password に事前登録すること）

tags = {
  Environment = "dev"
  Project     = "hbp-cc"
  CostCenter  = "dev"
}

# 検証済みドメインを指定（送信元ドメイン）。空の場合は SES モジュールは作成されない。
# Terraform 管理外とする（state rm 済み想定）。
ses_domain       = ""

# 既存 SES（Terraform 管理外・参照のみ）
ses_existing_domain = "janscore.com"
ses_existing_region = "us-west-2"
# 送信元アドレス（検証済み identity。ECS の EMAIL_FROM）
ses_sender_from_email = "Hello Baby Program <noreply@janscore.com>"

# カスタムドメイン（両方指定時のみ有効）。空の場合は xxx.cloudfront.net のまま。
# base_domain     = "xxxxx.com"
# route53_zone_id = "Z3QK1GRO4RD4HY"
# acm_existing_validation_record_names = ["_8b20608dc98bbd341afe22a806aeb9e9.xxxxx.com."]
