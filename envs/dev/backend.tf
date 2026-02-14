# ステートは S3 に保存。事前に bootstrap/ でバケット・DynamoDB を作成すること。
terraform {
  backend "s3" {
    bucket         = "hbp-cc-terraform-state"
    key            = "hbp-cc-infra/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
