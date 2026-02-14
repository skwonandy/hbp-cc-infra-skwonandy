terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ブートストラップ自体のステートはローカルでよい（一度だけ実行し、以後ほぼ触らない想定）
  backend "local" {
    path = "terraform.tfstate"
  }
}
