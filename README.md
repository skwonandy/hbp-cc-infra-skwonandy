# hbp-cc-infra

hbp-cc アプリケーションの AWS インフラを Terraform で管理する **専用リポジトリ**。環境は sandbox / dev / stg / prod。差異はサイズ（tfvars）のみ。

## 前提

- Terraform >= 1.5.0
- AWS CLI 設定済み（または環境変数 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`）
- 各環境の `backend.tf` は初期状態で **local** バックエンド。S3 バックエンドに切り替える場合は、バケットと DynamoDB テーブル作成後に `backend.tf` のコメントを入れ替え、`terraform init -reconfigure` を実行する

## ディレクトリ

- `envs/sandbox`, `envs/dev`, `envs/stg`, `envs/prod` … 環境ごとのルートモジュール（main.tf で modules を呼び出す）
- `modules/vpc`, `modules/rds`, … … 再利用可能なモジュール

## 使い方

```bash
# リポジトリルートが hbp-cc-infra の場合
cd envs/sandbox

# 初期化（プロバイダ取得。初回のみ）
terraform init

# 計画確認（RDS を使う環境は db_password を渡す）
terraform plan -var "db_password=YOUR_SECRET"

# 適用（AWS にリソース作成）
terraform apply -var "db_password=YOUR_SECRET"
# または: export TF_VAR_db_password=YOUR_SECRET のうえで terraform apply
```

- **RDS を有効にしている環境（sandbox 等）**: `db_password` は tfvars に書かず、`-var "db_password=..."` または環境変数 `TF_VAR_db_password` で渡す。
別の環境で作業する場合は `cd envs/dev` などに切り替え、同様に `init` → `plan` → `apply`。

## 実装状況

- **vpc**: 実装済み（VPC、パブリック/プライベートサブネット、NAT、SG）
- **rds**, **elasticache**: 実装済み。**sandbox** から呼び出し済み（RDS は `db_password` を `-var` または `TF_VAR_db_password` で渡す）
- **s3**: 実装済み（アプリ用・フロント用バケット、SSE・バージョニング・パブリックブロック）。**sandbox** から呼び出し済み
- **batch**: 実装済み（Fargate compute env、job queue `{env}_default`、job definition `{env}_fastapi_default_job`）。**sandbox** から呼び出し済み
- **cicd**: ECR のみ実装済み（API / worker / frontend 用リポジトリ）。**sandbox** から呼び出し済み。アプリの接続方法は [envs/sandbox/CONNECT.md](envs/sandbox/CONNECT.md) を参照
- **alb**, **ecs**, **cloudfront**, **ses**, **sqs**, **route53**, **acm**, **monitoring**: 雛形（variables.tf / README 等）。必要に応じて main.tf を実装する

## 参考・プラン

- **詳細プラン**: ルート直下の [initialPlan.md](initialPlan.md) を参照。構成図（Mermaid）、環境・モジュール対応、医療系 SaaS の暗号化・監査・VPC エンドポイント、CI/CD（GitHub Actions / CodeDeploy ブルーグリーン）、実装の進め方（1〜13）が記載されている。
- **実装の進め方（抜粋）**: 1) 骨組み・versions.tf・backend 2) VPC 3) RDS + ElastiCache 4) ECS + ALB（ブルーグリーン・Auto Scaling）5) S3 6) Route53 + ACM 7) CloudFront 8) Batch 9) SES + SQS 10) monitoring 11) cicd（ECR・OIDC・CodeDeploy）12) sandbox 用 tfvars 13) stg / prod
- **環境差**: sandbox / dev / stg / prod の差は **サイズのみ**（`instance_class`・`task_cpu`・`task_memory`・`task_count`・`storage_gb`・`az_count`・`multi_az`・`enable_pitr` を tfvars で指定）。構成（VPC エンドポイント・Batch・監査・暗号化）は全環境同一。
