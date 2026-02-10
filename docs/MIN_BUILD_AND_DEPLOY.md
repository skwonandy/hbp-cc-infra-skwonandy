# min 環境の構築とフロント・バックエンドのデプロイ

min 環境を Terraform で構築し、バックエンド（API）とフロントエンドをデプロイする手順です。

## 前提条件

- **Terraform**: 1.5.0 以上（`terraform version`）
- **AWS CLI**: 認証済み（`aws sts get-caller-identity`）
- **Node.js / npm**: フロントビルド用（hbp-cc の `front/` で `npm ci` 可能であること）
- **Docker**: バックエンドイメージビルド・push 用

---

## Phase 1: min の Terraform 構築

### 1.1 作業ディレクトリと初期化

```bash
cd hbp-cc-infra/envs/min
terraform init
```

### 1.2 変数の確認

- `terraform.tfvars` で `env` / `aws_region` / `az_count` / `vpc_cidr` 等を確認。
- **RDS パスワード**は tfvars に書かず、環境変数または `-var` で渡す。

### 1.3 計画と適用

```bash
# パスワードを環境変数で渡す場合
export TF_VAR_db_password="your-secure-rds-password"

terraform plan -out=tfplan
terraform apply tfplan
```

適用後、次のリソースが作成されます。

- VPC / サブネット / セキュリティグループ
- RDS（PostgreSQL）
- ElastiCache（Redis）
- S3（アプリ用・フロント用バケット）
- ECR（API 用・フロント用リポジトリ。worker は min では作成しない）
- ALB（ブルー/グリーン用 2 ターゲットグループ）
- ECS（API 用 Fargate サービス、CodeDeploy ブルー/グリーン）
- CloudFront（フロント用、S3 オリジン）

### 1.4 接続情報とエンドポイントの取得

```bash
cd hbp-cc-infra/envs/min
terraform output
```

主な output:
- **api_url**: API のエンドポイント（ALB。例: `http://hbp-cc-min-alb-xxx.ap-northeast-1.elb.amazonaws.com`）
- **frontend_url**: フロントの URL（CloudFront。例: `https://d1234abcd.cloudfront.net`）
- **cloudfront_distribution_id**: キャッシュ無効化用（GitHub Environment の `CLOUDFRONT_DISTRIBUTION_ID` に登録推奨）
- その他: `ecr_api_url`, `ecr_frontend_url`, `s3_frontend_bucket`, `rds_endpoint`, `redis_endpoint`, `s3_app_bucket`

詳細は [envs/min/CONNECT.md](../envs/min/CONNECT.md) を参照。

---

## Phase 2: バックエンドのデプロイ

min では worker は使わず、API のみ ECS（Fargate）で稼働します。ALB 経由で公開され、**api_url**（`terraform output api_url`）でアクセスできます。デプロイは **GitHub Actions の Deploy Backend** ワークフロー（ECR push → 新タスク定義リビジョン → CodeDeploy ブルー/グリーン）で行います。手動で行う場合は以下です。

### 2.1 ECR にログイン

```bash
AWS_REGION=ap-northeast-1
ECR_HOST=$(cd hbp-cc-infra/envs/min && terraform output -raw ecr_api_url | cut -d/ -f1)
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_HOST"
```

### 2.2 API イメージのビルドと push

hbp-cc リポジトリのルートで実行します。

```bash
# hbp-cc のルートで
cd path/to/hbp-cc

ECR_API_URL=$(cd path/to/hbp-cc-infra/envs/min && terraform output -raw ecr_api_url)
IMAGE_TAG=latest

docker build -t hbp-cc-api:"$IMAGE_TAG" -f server/fastapi/Dockerfile server/fastapi
docker tag hbp-cc-api:"$IMAGE_TAG" "$ECR_API_URL:$IMAGE_TAG"
docker push "$ECR_API_URL:$IMAGE_TAG"
```

### 2.3 バックエンドの実行

- Terraform 適用後、ECS サービスが ALB の blue ターゲットグループにタスクを登録します。**api_url** で API にアクセスできます。
- イメージ更新時は GitHub Actions の **Deploy Backend** を実行するか、手動で ECR push 後に CodeDeploy でデプロイしてください。詳細は [DEPLOY_BACKEND.md](DEPLOY_BACKEND.md) を参照。

---

## Phase 3: フロントエンドのデプロイ

フロントはビルド成果物を S3 にアップロードし、**CloudFront** 経由で配信されます。**frontend_url**（`terraform output frontend_url`）でアクセスできます。デプロイは **GitHub Actions の Deploy Frontend** ワークフロー（ビルド → S3 sync → CloudFront 無効化）で行います。

### 3.1 フロントのビルド

hbp-cc の `front/` で production ビルドします。

```bash
# hbp-cc/front で
cd path/to/hbp-cc/front
npm ci
npm run build
# 成果物: dist/front/browser/ に出力される想定（Angular のバージョンにより dist/ 配下のパスは要確認）
```

### 3.2 S3 にアップロード

min のフロント用バケット名を取得し、ビルド出力を sync します。

```bash
# hbp-cc のルートで実行。BUCKET 取得は hbp-cc-infra のパスを実際のパスに置き換える
BUCKET=$(cd path/to/hbp-cc-infra/envs/min && terraform output -raw s3_frontend_bucket)
AWS_REGION=ap-northeast-1

# Angular 21 の production ビルド出力は front/dist/front/browser/（要確認）
aws s3 sync front/dist/front/browser/ "s3://$BUCKET/" --region "$AWS_REGION" --delete
```

- `--delete`: バケット側にのみある古いファイルを削除します。
- キャッシュ制御が必要な場合は `--cache-control "max-age=31536000"` 等を付与してください。

### 3.3 フロントの配信

- Terraform で CloudFront ディストリビューション（S3 オリジン、OAC）が作成されています。**frontend_url** で HTTPS 配信されます。
- デプロイ後にキャッシュを更新するには、GitHub の Environment「min」に **CLOUDFRONT_DISTRIBUTION_ID**（`terraform output -raw cloudfront_distribution_id`）を登録しておくと、Deploy Frontend ワークフローが自動で invalidation を実行します。

---

## Phase 4: ブランチ push での自動デプロイ（GitHub Actions）

**環境ごとに YAML を分けず**、共通のワークフロー 2 本で min / dev / stg / prod に対応しています。

| ワークフロー | トリガー | 処理 |
|-------------|----------|------|
| `deploy-backend.yml` | push  to `min` / `dev` / `stg` / `prod`、かつ `server/**` に変更 | ブランチ名を環境として ECR（`hbp-cc-<環境>-api`）に push |
| `deploy-frontend.yml` | 上記と同じブランチ、かつ `front/**` に変更 | ブランチ名を環境として S3（`hbp-cc-<環境>-frontend`）に sync |

ブランチ名（`github.ref_name`）がそのまま環境名になります（例: `min` ブランチ → 環境 `min` → ECR `hbp-cc-min-api`）。

### 必要な GitHub 設定（hbp-cc リポジトリ）

**アクセスキーは使わず、OIDC で IAM ロールを assume する方式**です。各 Environment に登録するのは **1 つだけ**です。

1. **Settings → Environments** で `min` / `dev` / `stg` / `prod` を作成（使う分だけで可）。
2. 各 Environment を開き **Environment secrets** に登録：
   - **`AWS_DEPLOY_ROLE_ARN`** … その環境用の IAM ロール ARN（必須。例: `arn:aws:iam::015432574254:role/hbp-cc-github-deploy-min`）
   - **`CLOUDFRONT_DISTRIBUTION_ID`** … フロントの CloudFront 配布 ID（任意。登録すると Deploy Frontend でキャッシュ無効化を実行。`terraform output -raw cloudfront_distribution_id`）

ワークフロー側では `environment: ${{ github.ref_name }}` により、push したブランチと同じ名前の Environment のシークレットが使われます。

### AWS 側の準備（Terraform で OIDC ロールを生成）

**modules/cicd** で GitHub OIDC プロバイダ（アカウント 1 回）とデプロイ用 IAM ロールを定義しています。

1. **min で OIDC プロバイダとロールを作る**  
   `envs/min/terraform.tfvars` で以下を有効にし、`terraform apply` を実行する。
   ```hcl
   github_org_repo      = "skwonandy/hbp-cc-skwonandy"
   create_oidc_provider = true   # アカウントで 1 回だけ true（通常は min）
   ```
2. **ロール ARN を GitHub に登録**  
   適用後に出力される ARN を、GitHub の Environment「min」の **Environment secrets** に **`AWS_DEPLOY_ROLE_ARN`** として登録する。
   ```bash
   cd hbp-cc-infra/envs/min
   terraform output github_actions_deploy_role_arn
   ```
3. **他環境（dev / stg / prod）**  
   同じアカウントなら OIDC プロバイダは 1 回でよい。各環境の `main.tf` で cicd に `github_org_repo = "skwonandy/hbp-cc-skwonandy"` と `create_oidc_provider = false` を渡し、apply 後にその環境の `github_actions_deploy_role_arn` を GitHub の対応する Environment の `AWS_DEPLOY_ROLE_ARN` に登録する。

---

## Phase 5: デプロイに必要な IAM 権限

GitHub Actions または手動デプロイで必要な IAM 権限の詳細です。

### GitHub Actions デプロイ用 IAM ロール

Terraform の `modules/cicd` で作成される IAM ロール（`hbp-cc-github-deploy-<env>`）に付与される権限：

#### 1. ECR 認証・プッシュ
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken"
  ],
  "Resource": "*"
},
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:BatchCheckLayerAvailability",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload"
  ],
  "Resource": "arn:aws:ecr:ap-northeast-1:*:repository/hbp-cc-<env>-api"
}
```

#### 2. ECS タスク定義の登録
```json
{
  "Effect": "Allow",
  "Action": [
    "ecs:DescribeServices",
    "ecs:DescribeTaskDefinition",
    "ecs:RegisterTaskDefinition",
    "ecs:ListTaskDefinitions"
  ],
  "Resource": "*"
}
```

#### 3. IAM PassRole（ECS タスク実行用）
```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*",
  "Condition": {
    "StringLike": {
      "iam:PassedToService": "ecs-tasks.amazonaws.com"
    }
  }
}
```

#### 4. CodeDeploy デプロイ実行
```json
{
  "Effect": "Allow",
  "Action": [
    "codedeploy:CreateDeployment",
    "codedeploy:GetDeployment",
    "codedeploy:GetDeploymentConfig",
    "codedeploy:GetApplication",
    "codedeploy:GetApplicationRevision",
    "codedeploy:RegisterApplicationRevision",
    "codedeploy:GetDeploymentGroup",
    "codedeploy:ListDeployments",
    "codedeploy:StopDeployment"
  ],
  "Resource": "*"
}
```

#### 5. S3 フロントエンドデプロイ
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ],
  "Resource": [
    "arn:aws:s3:::hbp-cc-<env>-frontend",
    "arn:aws:s3:::hbp-cc-<env>-frontend/*"
  ]
}
```

#### 6. CloudFront Invalidation
```json
{
  "Effect": "Allow",
  "Action": [
    "cloudfront:CreateInvalidation",
    "cloudfront:GetDistribution"
  ],
  "Resource": "*"
}
```

### 権限の確認方法

デプロイロールの ARN を取得し、AWS コンソールで権限を確認：

```bash
cd hbp-cc-infra/envs/min
terraform output github_actions_deploy_role_arn

# 出力例: arn:aws:iam::015432574254:role/hbp-cc-github-deploy-min
```

AWS コンソール → IAM → Roles → `hbp-cc-github-deploy-min` → Permissions で確認できます。

### 手動デプロイ時の注意

手動で AWS CLI を使ってデプロイする場合は、上記と同等の権限を持つ IAM ユーザーまたはロールが必要です。特に以下の権限が不足しているとエラーになります：

- `codedeploy:CreateDeployment` - CodeDeploy デプロイを実行できない
- `ecs:RegisterTaskDefinition` - 新しいタスク定義を登録できない
- `iam:PassRole` - ECS タスクに IAM ロールを渡せない

---

## チェックリスト

- [ ] Phase 1: `terraform init` / `plan` / `apply` で min を構築した（`TF_VAR_db_password` を設定済み）
- [ ] Phase 2: GitHub Actions の Deploy Backend を実行するか、手動で ECR push + CodeDeploy で API をデプロイした
- [ ] Phase 3: GitHub Actions の Deploy Frontend を実行するか、手動でビルド・S3 sync した（任意で `CLOUDFRONT_DISTRIBUTION_ID` を登録すると invalidation あり）
- [ ] Phase 4: GitHub の Environment「min」に `AWS_DEPLOY_ROLE_ARN` を登録した（任意で `CLOUDFRONT_DISTRIBUTION_ID` も）
- [ ] **api_url** と **frontend_url** でアクセスできることを確認した

---

## トラブルシューティング

### API (api_url) が 503 になる

- **原因**: ALB の背後に healthy なターゲットがいない。多くは ECS タスクの起動失敗（必須環境変数不足で FastAPI が起動前にクラッシュしている）。
- **対応**:
  1. Terraform の ECS モジュールで `service_url` / `app_env` / `DB_POOL_SIZE` / `DB_HOST_REPLICATIONS` および JWT 系（`api_extra_environment`）が渡されていることを確認する（envs/min の `module.ecs` 参照）。
  2. **タスク定義を変更したあとは、CodeDeploy で再デプロイが必要**。GitHub Actions の **Deploy Backend** を実行（min ブランチへ push または workflow_dispatch）すると、最新タスク定義（必須環境変数入り）でタスクが立ち上がる。
  3. **「Primary taskset target group must be behind listener」** のとき: ECS の primary が green なのにリスナーが blue を向いている。`envs/min` で `alb_listener_default_target_group = "green"` にして `terraform apply` し、その後 **Deploy Backend (switch to latest task def)** を実行。デプロイ成功後に `alb_listener_default_target_group = "blue"` に戻して apply する。
  4. **サービスが INACTIVE な古い rev を参照したまま**（Deploy Backend を実行してもタスクが 0 のまま）のとき: **Deploy Backend (switch to latest task def)** ワークフローを手動実行する。イメージビルドなしで、既存の最新タスク定義を指定して CodeDeploy のみ実行し、サービスを最新 rev に切り替える。それでも失敗する場合は CodeDeploy のデプロイ結果（Failure reason）と ECS/CloudWatch Logs で原因を確認する。
  5. まだ 503 のとき: ECS コンソールでサービス「hbp-cc-min-api」のタスクが Running か、停止を繰り返していないか確認。CloudWatch Logs（`/ecs/hbp-cc-min-api`）で起動時エラー（DB/Redis 接続、KeyError 等）を確認する。

### 「No Container Instances were found in your cluster」（Fargate でも発生）

- **原因**: ECS サービスが参照している**タスク定義が INACTIVE**（登録解除済み）のため、タスクを配置できない。Terraform でタスク定義を差し替えたあと、サービスは `lifecycle { ignore_changes = [task_definition] }` のため古い rev を参照したままになる。CodeDeploy 運用では API からサービス側のタスク定義を更新できないため、この状態でデプロイしても新タスクが 1 本も起動しない。
- **確認**: `aws ecs describe-services ... --query 'services[0].taskDefinition'` で rev を確認し、`aws ecs describe-task-definition --task-definition hbp-cc-min-api:1` で `status: INACTIVE` ならこの状態。
- **復旧（サービス再作成）**: サービスを一度削除し、Terraform で作り直すと、**アクティブなタスク定義**（Terraform が管理するリビジョン）でサービスが作成される。
  1. 進行中の CodeDeploy デプロイがあれば停止: `aws deploy stop-deployment --deployment-id <id> --region ap-northeast-1`
  2. ECS サービスを削除（コンソールまたは CLI）: `aws ecs delete-service --cluster hbp-cc-min-cluster --service hbp-cc-min-api --region ap-northeast-1 --force`
  3. 削除完了を待つ（数分）。その後 Terraform の state からサービスを外す:  
     `cd envs/min && terraform state rm 'module.ecs.aws_ecs_service.api'`
  4. `terraform apply`（`db_password` を渡す）でサービスを再作成。作成されるサービスは Terraform のタスク定義（アクティブな rev）を参照する。
  5. 必要に応じて **Deploy Backend** または **Deploy Backend (switch to latest task def)** を再実行する。

---

## min 環境の破棄

min 環境を完全に削除する場合は、専用の破棄スクリプトを使用します。

### 破棄スクリプトの使い方

```bash
cd hbp-cc-infra/envs/min

# RDS パスワードを環境変数に設定
export TF_VAR_db_password="your-secure-rds-password"

# 破棄スクリプトを実行
./destroy.sh
```

### スクリプトが実行する処理

1. **S3 バケットのクリーンアップ**
   - `hbp-cc-min-frontend`: すべてのオブジェクト、バージョン、削除マーカーを削除
   - `hbp-cc-min-app`: すべてのオブジェクト、バージョン、削除マーカーを削除

2. **ECR リポジトリのクリーンアップ**
   - `hbp-cc-min-api`: すべての Docker イメージを削除
   - `hbp-cc-min-frontend`: すべての Docker イメージを削除

3. **Terraform destroy**
   - すべてのインフラリソースを削除

### 注意事項

- **データは完全に失われます**: この操作は取り消せません
- **確認プロンプト**: スクリプト実行時に `yes` の入力が必要です
- **RDS パスワード**: `TF_VAR_db_password` の設定が必須です

### 手動で破棄する場合

スクリプトを使わず手動で破棄する場合は、以下の順序で実行：

```bash
cd hbp-cc-infra/envs/min

# 1. S3 バケットを空にする
aws s3 rm s3://hbp-cc-min-frontend --recursive --region ap-northeast-1
aws s3 rm s3://hbp-cc-min-app --recursive --region ap-northeast-1

# 2. S3 バージョンを削除（バケットがバージョニング有効の場合）
aws s3api list-object-versions --bucket hbp-cc-min-frontend --region ap-northeast-1 \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json | \
  jq '{Objects: .}' | \
  aws s3api delete-objects --bucket hbp-cc-min-frontend --delete file:///dev/stdin --region ap-northeast-1

# 3. ECR イメージを削除
aws ecr batch-delete-image \
  --repository-name hbp-cc-min-api \
  --image-ids "$(aws ecr list-images --repository-name hbp-cc-min-api --region ap-northeast-1 --query 'imageIds' --output json)" \
  --region ap-northeast-1

# 4. Terraform destroy
export TF_VAR_db_password="your-password"
terraform destroy
```

---

## 参考

- [envs/min/CONNECT.md](../envs/min/CONNECT.md) — 接続情報と環境変数の対応
- [DEPLOY_BACKEND.md](DEPLOY_BACKEND.md) — バックエンドのデプロイ手順の詳細
- [initialPlan.md](../initialPlan.md) — インフラ全体のプラン（min の位置づけ、未実装の ECS/CloudFront 等）
