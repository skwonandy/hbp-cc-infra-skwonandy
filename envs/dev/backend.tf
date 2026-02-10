# 本番運用時は S3 バックエンドに切り替える（下記のコメントを有効化し、local を削除）
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
  # backend "s3" {
  #   bucket         = "hbp-cc-terraform-state"
  #   key            = "hbp-cc-infra/dev/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}
