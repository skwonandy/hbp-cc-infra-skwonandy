# ブートストラップ（Terraform ステート用リソース）

envs/dev, stg, prod の Terraform が使う **リモートステート用の S3 バケットと DynamoDB ロックテーブル** を一度だけ作成する。

## 実行タイミング

**各環境で初めて `terraform apply` する前に、このディレクトリで 1 回だけ実行する。**

## 手順

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

デフォルトで以下が作成される。

- S3 バケット: `hbp-cc-terraform-state`（バージョニング・暗号化・パブリックアクセスブロック有効）
- DynamoDB テーブル: `terraform-locks`（Pay-per-request、LockID をキー）

リージョンは `ap-northeast-1`（変数で変更可）。作成後、リポジトリルートに戻り、`envs/<env>` で `terraform init` → `plan` → `apply` を実行する。
