# hbp-cc-infra

hbp-cc アプリケーションの AWS インフラを Terraform で管理する **専用リポジトリ**。環境は sandbox / dev / stg / prod。差異はサイズ（tfvars）のみ。

## 前提

- Terraform 1.14.4
- AWS CLI 設定済み（または環境変数 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`）
- 各環境の `backend.tf` は初期状態で **local** バックエンド。S3 バックエンドに切り替える場合は、バケットと DynamoDB テーブル作成後に `backend.tf` のコメントを入れ替え、`terraform init -reconfigure` を実行する
