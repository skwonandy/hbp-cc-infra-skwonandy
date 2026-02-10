# min 環境へアプリをつなぐ

**min** は dev より低スペック（最小スペック）で AWS に全てデプロイする環境です。**最低限の動作**のため、min では **arq worker**・**AWS Batch**・**SQS** は使わず、API と DB・Redis・S3・ECR のみを利用します。

- **min の構築とフロント・バックエンドのデプロイ手順**: [docs/MIN_BUILD_AND_DEPLOY.md](../../docs/MIN_BUILD_AND_DEPLOY.md)

`terraform output` で取得できる値と、hbp-cc アプリの環境変数の対応です。

## 1. 接続情報の取得

```bash
cd envs/min
terraform output
```

## 2. 環境変数（アプリが min のリソースを参照する場合）

アプリ（FastAPI）の `docker-compose` や `.env` で使う想定です。**RDS と Redis は VPC のプライベートサブネット内にあるため、インターネットからは直接接続できません。** 接続方法は「4. ネットワーク」を参照してください。

| 環境変数 | 設定例（terraform output から） | 備考 |
|----------|----------------------------------|------|
| **DB** | | |
| `DB_HOST` | RDS のホスト（`:5432` より前） | 例: `hbp-cc-min-postgres.xxx.ap-northeast-1.rds.amazonaws.com` |
| `DB_NAME` | `main` | RDS で作成済み |
| `DB_USER` | `postgres` | |
| `DB_PASSWORD` | apply 時に渡した値 | tfvars には書かない |
| **Redis** | | |
| `REDIS_HOST` | `redis_endpoint` の**ホスト部分のみ**（`:6379` を除く） | 例: `hbp-cc-min-redis.xxx.0001.apne1.cache.amazonaws.com` |
| **S3** | | |
| `AWS_S3_*` | IAM で S3 アクセス可能な認証情報を使用 | バケット名: `s3_app_bucket` の値（`hbp-cc-min-app`） |
| **Batch** | — | min では Batch を作成しない（ジョブ実行を行わない） |
| **SQS** | — | min では SQS を作成しない。メール（MFA 含む）は **SES 直接**で送るため不要 |
| **SES** | 要設定 | ログイン時 MFA（OTP メール）などは **SES** で送信（`usecase_auth.py` 等で `AwsService.SES`）。送信元の検証と ECS タスクの IAM に `ses:SendEmail` 等を付与すること |
| **ECR** | | イメージ push 先 |
| API イメージ | `ecr_api_url` + `:tag` | 例: `015432574254.dkr.ecr.ap-northeast-1.amazonaws.com/hbp-cc-min-api:latest` |
| Worker イメージ | — | min では worker をデプロイしないため ECR なし（`ecr_worker_url` は null） |
| Frontend イメージ | `ecr_frontend_url` + `:tag` | |

## 3. ECR への push

```bash
# ECR ログイン（AWS CLI の認証情報を使用）
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 015432574254.dkr.ecr.ap-northeast-1.amazonaws.com

# 例: API イメージをビルドして push
docker build -t hbp-cc-min-api:latest -f server/fastapi/Dockerfile server/fastapi
docker tag hbp-cc-min-api:latest 015432574254.dkr.ecr.ap-northeast-1.amazonaws.com/hbp-cc-min-api:latest
docker push 015432574254.dkr.ecr.ap-northeast-1.amazonaws.com/hbp-cc-min-api:latest
```

## 4. ネットワーク（RDS / Redis への到達方法）

RDS と ElastiCache は**プライベートサブネット**にあり、インターネットから直接アクセスできません。

- **アプリを ECS で VPC 内にデプロイする場合**  
  → 同じ VPC 内なので、上記の `DB_HOST` / `REDIS_HOST` をそのまま使えます。ECS 実装後にタスク定義の環境変数に設定してください。

- **手元の PC や CI から接続したい場合**  
  - **オプション A**: 踏み台（Bastion）＋ SSH ポートフォワード、または **AWS Systems Manager Session Manager** のポートフォワードで、ローカルの 5432/6379 を RDS/Redis に転送する。  
  - **オプション B**: min では「DB と Redis は従来どおり docker-compose の db/redis を使い、AWS は S3・Batch・ECR だけ使う」運用にする。

## 5. S3 バケット名とアプリの対応

アプリの `_types/_aws.py` 等で参照するバケット名は環境変数で上書きできます。min のアプリ用バケットは `hbp-cc-min-app` です。

- `AWS_S3_TEMPORARY_BUCKET_NAME` → `hbp-cc-min-app`（またはアプリ用プレフィックスを検討）
- その他 S3 バケット用 env も、必要に応じて `hbp-cc-min-app` を指すように設定

（アプリが複数バケットを前提にしている場合は、min では 1 バケット内でプレフィックス分けにするか、必要なら Terraform でバケットを追加してください。）

## 6. IAM ユーザー janscore に CodeDeploy list/stop を付与する

Terraform 実行用ユーザー **janscore** で CodeDeploy のデプロイ一覧・停止を行うには、`envs/min/terraform-min-policy.json` をインラインポリシーとして適用する。

```bash
cd envs/min
aws iam put-user-policy \
  --user-name janscore \
  --policy-name TerraformMinDeployInline \
  --policy-document file://terraform-min-policy.json
```

既に同じポリシー名で付与している場合は上記で更新される。ポリシーには `codedeploy:ListDeployments`, `codedeploy:GetDeployment`, `codedeploy:StopDeployment` を含む。
