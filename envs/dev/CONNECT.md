# dev 環境へアプリをつなぐ

**dev** は開発用のフルスタック環境です。**最低限の動作**のため、dev では **arq worker**・**AWS Batch**・**SQS** は使わず、API と DB・Redis・S3・ECR のみを利用します。

- **dev の構築とフロント・バックエンドのデプロイ手順**: [docs/DEV_BUILD_AND_DEPLOY.md](../../docs/DEV_BUILD_AND_DEPLOY.md)

---

## 1. Terraform の実行

```bash
cd envs/dev
terraform init
export TF_VAR_db_password="your-secure-password"
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 2. 環境変数（アプリが dev のリソースを参照する場合）

| 変数 | 内容 | 例 |
|------|------|-----|
| `DB_HOST` | RDS のホスト（`:5432` より前） | 例: `hbp-cc-dev-postgres.xxx.ap-northeast-1.rds.amazonaws.com` |
| `DB_NAME` | データベース名 | `main` |
| `DB_USER` | 接続ユーザ | `postgres` |
| `DB_PASSWORD` | RDS マスタパスワード | Terraform に渡した値 |
| `REDIS_HOST` | `redis_endpoint` の**ホスト部分のみ**（`:6379` を除く） | 例: `hbp-cc-dev-redis.xxx.0001.apne1.cache.amazonaws.com` |
| `AWS_S3_*` | IAM で S3 アクセス可能な認証情報を使用 | バケット名: `s3_app_bucket` の値（`hbp-cc-dev-app`） |
| **Batch** | — | dev では Batch を作成しない（ジョブ実行を行わない） |
| **SQS** | — | dev では SQS を作成しない。メール（MFA 含む）は **SES 直接**で送るため不要 |

---

## 3. Docker イメージ（手動デプロイ時）

| 種別 | 参照先 | 例 |
|------|--------|-----|
| API イメージ | `ecr_api_url` + `:tag` | 例: `015432574254.dkr.ecr.ap-northeast-1.amazonaws.com/hbp-cc-dev-api:latest` |
| Worker イメージ | — | dev では worker をデプロイしないため ECR なし（`ecr_worker_url` は null） |

手動で API イメージを push する例:

```bash
docker build -t hbp-cc-dev-api:latest -f server/fastapi/Dockerfile server/fastapi
docker tag hbp-cc-dev-api:latest <ecr_api_url>:latest
docker push <ecr_api_url>:latest
```

---

## 4. オプション（ハイブリッド運用）

- **オプション B**: dev では「DB と Redis は従来どおり docker-compose の db/redis を使い、AWS は S3・Batch・ECR だけ使う」運用にする。

アプリの `_types/_aws.py` 等で参照するバケット名は環境変数で上書きできます。dev のアプリ用バケットは `hbp-cc-dev-app` です。

- `AWS_S3_TEMPORARY_BUCKET_NAME` → `hbp-cc-dev-app`（またはアプリ用プレフィックスを検討）
- その他 S3 バケット用 env も、必要に応じて `hbp-cc-dev-app` を指すように設定

（アプリが複数バケットを前提にしている場合は、dev では 1 バケット内でプレフィックス分けにするか、必要なら Terraform でバケットを追加してください。）

---

## 5. CodeDeploy 用 IAM（手動操作時）

Terraform 実行用ユーザーで CodeDeploy のデプロイ一覧・停止を行うには、dev 用のインラインポリシーを適用する。必要な権限は [docs/DEV_BUILD_AND_DEPLOY.md](../../docs/DEV_BUILD_AND_DEPLOY.md) の「Phase 5」を参照。

```bash
cd envs/dev
# ポリシー JSON を用意し、IAM ユーザーまたはロールにアタッチ
aws iam put-user-policy --user-name <user> --policy-name dev-codedeploy --policy-document file://terraform-dev-policy.json
```
