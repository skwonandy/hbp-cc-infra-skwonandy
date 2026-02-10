# ルートの backend はひな形。実際の state は envs/<env>/backend.tf で上書きする。
# 各環境で terraform init -reconfigure を実行する際に envs/<env> を -chdir で指定する。

# backend "s3" {
#   bucket         = "your-terraform-state-bucket"
#   key            = "hbp-cc-infra/${local.env}/terraform.tfstate"
#   region         = "ap-northeast-1"
#   dynamodb_table = "terraform-locks"
#   encrypt        = true
# }
