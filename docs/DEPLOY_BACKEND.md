# バックエンドのデプロイ手順

FastAPI（API）および arq worker を AWS にデプロイする手順です。イメージは ECR に push し、ECS で稼働させる前提です。

## 前提条件

- **Terraform 適用済み**: 対象環境で `terraform apply` が完了しており、ECR リポジトリ（API）が存在すること。**dev 環境では worker 用 ECR は作成されない**。
- **AWS 認証**: `aws configure` または環境変数で AWS 認証が済んでいること（`aws sts get-caller-identity` で確認）。
- **リポジトリ**: アプリ（hbp-cc）のルートで作業する想定。インフラ（hbp-cc-infra）は接続情報取得用に参照する。

---

## 1. デプロイ先の接続情報を取得する

対象環境の Terraform を適用したディレクトリで output を取得します。

```bash
# 例: dev 環境
cd hbp-cc-infra/envs/dev
terraform output
```

次の値を控えます（例は dev の場合）。

| output 名 | 用途 |
|-----------|------|
| `ecr_api_url` | API イメージの push 先 URL（例: `015432574254.dkr.ecr.ap-northeast-1.amazonaws.com/hbp-cc-dev-api`） |
| `ecr_worker_url` | Worker イメージの push 先 URL（**dev では null**。stg/prod のみ利用） |

リージョンは `terraform.tfvars` の `aws_region`（既定: `ap-northeast-1`）に従います。

---

## 2. ECR にログインする

```bash
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin 015432574254.dkr.ecr.ap-northeast-1.amazonaws.com
```

※ アカウント ID が異なる場合は、上記のホスト部分を `terraform output ecr_api_url` のドメインに合わせてください。

---

## 3. API イメージをビルドして ECR に push する

アプリ（hbp-cc）のリポジトリルートで実行します。

```bash
# リポジトリルート（hbp-cc/）で
export ECR_API_URL="<ecr_api_url の値>"   # 例: 015432574254.dkr.ecr.ap-northeast-1.amazonaws.com/hbp-cc-dev-api
export IMAGE_TAG="latest"   # または git commit SHA など

# ビルド
docker build -t hbp-cc-api:${IMAGE_TAG} -f server/fastapi/Dockerfile server/fastapi

# ECR 用にタグ付け
docker tag hbp-cc-api:${IMAGE_TAG} ${ECR_API_URL}:${IMAGE_TAG}

# push
docker push ${ECR_API_URL}:${IMAGE_TAG}
```

---

## 4. Worker イメージをビルドして ECR に push する（dev では不要）

**dev 環境では worker 用 ECR を作成していないため、この手順はスキップしてください。** stg / prod で worker をデプロイする場合のみ実行します。

Worker は API と同じ Dockerfile でビルドし、タスク定義側でコマンド（例: arq 起動）を差し替える運用を想定しています。別 Dockerfile がある場合はそのパスに読み替えてください。

```bash
export ECR_WORKER_URL="<ecr_worker_url の値>"
export IMAGE_TAG="latest"

docker build -t hbp-cc-worker:${IMAGE_TAG} -f server/fastapi/Dockerfile server/fastapi
docker tag hbp-cc-worker:${IMAGE_TAG} ${ECR_WORKER_URL}:${IMAGE_TAG}
docker push ${ECR_WORKER_URL}:${IMAGE_TAG}
```

---

## 5. ECS に反映する（ECS が Terraform でデプロイされている場合）

ECS モジュールを有効にしている環境では、新しいイメージでタスク定義のリビジョンを作成し、サービスを更新します。

### 5a. タスク定義の更新（新イメージでリビジョン作成）

- **AWS コンソール**: ECS → タスク定義 → 対象定義の「新規リビジョンの作成」で、API / Worker のコンテナイメージを `$(ecr_api_url):$(tag)` に更新。
- **AWS CLI 例**（タスク定義の JSON を取得し、`containerDefinitions[].image` を書き換えたうえで `register-task-definition`）:

```bash
# 現在のタスク定義を取得し、image のみ更新して登録する流れ
aws ecs describe-task-definition --task-definition <family> --query taskDefinition > taskdef.json
# taskdef.json の image を ECR の新タグに編集し、不要な項目（taskDefinitionArn, revision, status 等）を削除
aws ecs register-task-definition --cli-input-json file://taskdef.json
```

### 5b. サービスのデプロイ

- **ローリング更新**: サービスで「新しいデプロイの開始」を実行するか、CLI で強制新デプロイ。

```bash
aws ecs update-service --cluster <cluster_name> --service <service_name> --force-new-deployment
```

- **CodeDeploy ブルー/グリーン** を Terraform で組み込んでいる場合は、新タスク定義リビジョンで CodeDeploy のデプロイを開始し、検証後にトラフィックを green に切り替える流れになります。詳細は [initialPlan.md](../initialPlan.md) の「CI / CD」を参照してください。

---

## 6. GitHub Actions でのデプロイ（想定）

CI/CD では次の流れを想定しています。

1. **認証**: GitHub OIDC で AWS に認証（Terraform で IAM ロールを定義）。
2. **ビルド**: アプリリポジトリで API（および Worker）イメージをビルド。
3. **ECR push**: 上記と同じ手順を workflow 内で実行（`ecr_api_url` / `ecr_worker_url` は Terraform output または Secrets に格納）。
4. **ECS 更新**: 新タスク定義リビジョン登録 → サービスの強制新デプロイ、または CodeDeploy でブルー/グリーンデプロイ。

ワークフローは `deploy-backend.yml` でブランチ（development / staging / production）ごとにトリガーし、ブランチ名を dev/stg/prod にマッピングして ECR・ECS 名に使用します。OIDC と ECR 用 IAM は `modules/cicd` で管理します。

---

## チェックリスト（手動デプロイ時）

- [ ] 対象環境の `terraform output` で ECR URL を確認した
- [ ] `aws ecr get-login-password` で ECR にログインした
- [ ] API イメージをビルドし、正しい ECR リポジトリ・タグで push した
- [ ] （dev 以外で worker を運用している場合）Worker イメージも push した
- [ ] （ECS 利用時）タスク定義を新イメージで更新し、サービスを新デプロイした
