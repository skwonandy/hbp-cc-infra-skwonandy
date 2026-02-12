# hbp-cc-infra

hbp-cc アプリケーションの AWS インフラを Terraform で管理する **専用リポジトリ**。環境は **dev / stg / prod**。差異はサイズ（tfvars）のみ。

## リポジトリ構成

- **envs/** — 環境ごとのルートモジュール
  - `envs/dev/`, `envs/stg/`, `envs/prod/` で `main.tf`・`variables.tf`・`terraform.tfvars` を配置
- **modules/** — 再利用モジュール（vpc, rds, elasticache, s3, cicd, alb, ecs, cloudfront, ses, terraform-runner-policy, acm, route53, batch, sqs, monitoring など）
- **scripts/** — 運用スクリプト（例: `assume-terraform-role.sh` で Terraform 実行用ロールを assume）
- **versions.tf** — Terraform および AWS provider のバージョン制約

## 前提

- **Terraform 1.14.4**（`required_version = "= 1.14.4"`）
- **AWS provider** `~> 5.0`
- AWS CLI 設定済み（または環境変数 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`）

### Terraform の実行

**plan / apply の前に**、対象環境の RDS マスターパスワードを SSM Parameter Store に登録しておくこと（未登録だと `data "aws_ssm_parameter" "rds_password"` でエラーになる）。手順は後述の [RDS マスターパスワード（SSM のみ）](#rds-マスターパスワードssm-のみ) を参照。

対象環境のディレクトリで初期化・plan・apply を実行する。

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

### GitHub Actions と OIDC

アプリリポジトリのデプロイ workflow は、**GitHub Environment 名が Terraform の env（dev / stg / prod）と一致している必要があります**。リポジトリの Settings → Environments で **dev** / **stg** / **prod** の 3 つを作成し、各 Environment の Secrets に **`AWS_DEPLOY_ROLE_ARN`** のみ登録してください。CloudFront のキャッシュ無効化用の Distribution ID は、workflow 内で環境名（`hbp-cc-<env> frontend` の Comment）から自動取得するため、別途登録は不要です。ブランチ名は development / staging / production のままでよく、workflow 内で dev / stg / prod にマッピングされます。

## 初回デプロイまでのフロー

フロント・バックエンドを初めてデプロイするときは、以下の順序で行う。GitHub Secrets（`AWS_DEPLOY_ROLE_ARN`）は Terraform apply 後の output が必要。フロントのデプロイは SSM の `api-base-url`（Terraform 作成）に依存する。

```mermaid
flowchart LR
  subgraph prep [前提]
    A[AWS Terraform 準備]
    B[RDS パスワード SSM 登録]
  end
  subgraph infra [インフラ]
    C[Terraform apply]
  end
  subgraph gh [GitHub]
    D[Environment dev stg prod]
    E[Secrets AWS_DEPLOY_ROLE_ARN]
  end
  subgraph deploy [デプロイ]
    F[初回バックエンド]
    G[初回フロント]
  end
  subgraph verify [確認]
    H[API フロント動作確認]
  end
  A --> C
  B --> C
  C --> D
  C --> E
  D --> F
  E --> F
  C --> G
  E --> G
  F --> H
  G --> H
```

### 前提条件

- Terraform 1.14.4、AWS CLI 設定済み（上記「前提」参照）
- 対象環境の RDS マスターパスワードを SSM に登録済み（[RDS マスターパスワード（SSM のみ）](#rds-マスターパスワードssm-のみ) 参照）
- （任意）Terraform 実行用ロールを assume する場合は [assume の手順](#terraform-実行用ロール案-a-assume-運用) 参照

### Step 1: インフラの構築（Terraform）

対象環境（例: dev）で次を実行する。

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

**作成される主なリソース**: VPC, RDS, ElastiCache, S3（アプリ用・フロント用）, ECR（API 用）, ALB, ECS クラスタ・タスク定義・サービス（CodeDeploy ブルー/グリーン）, CloudFront（フロント用・API 用 HTTPS 配信）, SSM パラメータ（`/hbp-cc/<env>/api-base-url` は HTTPS・`/hbp-cc/<env>/service-url`）, GitHub Actions 用 IAM ロール（OIDC）。

**重要**: apply 後にデプロイ用ロール ARN を取得し、Step 2 で GitHub に登録する。

```bash
cd envs/dev && terraform output github_actions_deploy_role_arn
```

### Step 2: GitHub の設定

- **Environments**: アプリリポジトリの Settings → Environments で **dev** / **stg** / **prod** の 3 つを作成する。名前は必ず dev / stg / prod（OIDC の `environment:` と一致させる）。
- **Secrets**: 各 Environment の Secrets に **`AWS_DEPLOY_ROLE_ARN`** を 1 つだけ登録する。値は Step 1 の `terraform output github_actions_deploy_role_arn` の出力。
- CloudFront の Distribution ID は workflow 内で Comment（`hbp-cc-<env> frontend`）から自動取得するため、Secrets には登録不要。

### Step 3: 初回バックエンドデプロイ

**トリガー**

- **push**: `development` / `staging` / `production` のいずれかへ `server/**` の変更を push する。
- **手動**: Actions → "Deploy Backend" → "Run workflow" で対象（development / staging / production）を選択する。「Use workflow from」のブランチは選択した環境と一致させること（workflow の Validate でチェックされる）。

**処理の流れ**: ECR ログイン → API イメージをビルド（`server/fastapi/Dockerfile`）→ ECR へ push（`hbp-cc-<env>-api`）→ **ECS ワンショットタスクで `alembic upgrade head` を実行（マイグレーション）** → 既存 ECS タスク定義を取得して新イメージで新リビジョン登録 → CodeDeploy でブルー/グリーンデプロイ。

### Step 4: 初回フロントエンドデプロイ

**トリガー**

- **push**: `development` / `staging` / `production` のいずれかへ `front/**` の変更を push する。
- **手動**: Actions → "Deploy Frontend" → "Run workflow" で対象を選択する。ブランチと環境の一致が必要。

**処理の流れ**: `AWS_DEPLOY_ROLE_ARN` で OIDC 認証 → Node セットアップ・`npm ci` → SSM から `/hbp-cc/<env>/api-base-url` を取得し `front/scripts/set-api-base-url.js` で環境ファイル（`environment.dev.ts` 等）の `apiBaseUrl` を上書き → `build:dev` / `build:stg` / `build:prod` でビルド → `front/dist/front/browser/` を S3 `hbp-cc-<env>-frontend` に sync → CloudFront キャッシュ無効化（Comment `hbp-cc-<env> frontend` で Distribution を検索）。

**依存**: Terraform が SSM に `api-base-url` を登録しているため、Step 1 が完了していることが前提。

### Step 5: 動作確認

- **API**: `terraform output api_url` で表示される ALB の URL（例: `http://.../api`）にヘルスチェックやログイン等でアクセスする。
- **フロント**: `terraform output frontend_url` で表示される CloudFront URL にブラウザでアクセスする。
- 問題がある場合は ECS のタスク状態や CloudWatch Logs（`/ecs/hbp-cc-<env>-api`）を確認する。

### 補足

- **ブランチと env の対応**: development → dev, staging → stg, production → prod（workflow 内でマッピング）。
- **2 回目以降**: 上記 Step 3 / Step 4 のトリガー（push または手動）で同じ workflow を実行するだけ。

## Terraform 実行に必要な IAM 権限

`terraform apply` を実行する IAM ユーザー／ロールには、本リポジトリが作成・参照するリソースに対応した権限が必要です。

### 必要な権限の概要

本リポジトリの Terraform が扱う AWS サービスと、必要な権限の種類は以下のとおりです。

| サービス | 用途 | 主な権限の種類 |
|----------|------|----------------|
| **EC2** | VPC・サブネット・インターネットゲートウェイ・NAT ゲートウェイ・ルートテーブル・セキュリティグループ・EIP | Create*, Describe*, Delete*, Modify*, Associate*, Attach*, AllocateAddress など |
| **RDS** | DB サブネットグループ・DB インスタンス | CreateDBSubnetGroup, CreateDBInstance, Describe*, Delete*, Modify* など |
| **ElastiCache** | キャッシュサブネットグループ・Redis クラスタ | CreateCacheSubnetGroup, CreateCacheCluster, Describe*, Delete*, Modify* など |
| **S3** | アプリ用・フロントエンド用バケット（バージョニング・暗号化・パブリックアクセスブロック・バケットポリシー） | CreateBucket, PutBucket*, GetBucket*, DeleteBucket など |
| **IAM** | GitHub OIDC プロバイダ・デプロイ用ロール・ECS タスク実行ロール・タスクロール・CodeDeploy ロール・ポリシー | CreateOpenIDConnectProvider, CreateRole, CreatePolicy, PutRolePolicy, AttachRolePolicy, GetRole, GetPolicy など |
| **ECR** | API・Worker 用リポジトリ | CreateRepository, PutLifecyclePolicy, GetAuthorizationToken など |
| **Elastic Load Balancing** | ALB・ターゲットグループ・リスナー・リスナールール | CreateLoadBalancer, CreateTargetGroup, CreateListener, CreateRule, Describe*, Delete*, Modify* など |
| **ECS** | クラスタ・タスク定義・サービス | CreateCluster, RegisterTaskDefinition, CreateService, Describe*, Update*, Delete* など |
| **CodeDeploy** | ECS 用アプリケーション・デプロイメントグループ | CreateApplication, CreateDeploymentGroup, GetDeploymentGroup など |
| **CloudWatch Logs** | ECS API 用ロググループ | CreateLogGroup, PutRetentionPolicy, DescribeLogGroups, DeleteLogGroup など |
| **CloudFront** | 配信・Origin Access Control | CreateDistribution, CreateOriginAccessControl, Get*, Update*, Delete* など |
| **SSM Parameter Store** | RDS パスワードの参照（data）・api-base-url / service-url の作成 | GetParameter, PutParameter, DeleteParameter, AddTagsToResource（詳細は下記） |
| **SES** | ドメイン・メール identity（SES モジュール有効時） | VerifyDomainIdentity, VerifyEmailIdentity, GetIdentityVerificationAttributes など |
| **STS** | 呼び出し元 identity の取得（data） | GetCallerIdentity |


### Terraform 実行用ロール（assume 運用）

ARN 制限付きのポリシーと **Terraform 実行用ロール** は [modules/terraform-runner-policy](modules/terraform-runner-policy) で定義されています。環境（dev / stg / prod）ごとに、その環境のリソースにのみ権限が限定されたロールが作成されます。

**Terraform 実行者が持つ権限（2 回目以降）**: **Terraform 実行用ロールを assume する権限だけ**にしてください（PowerUserAccess は付けない）。そうすることで、Terraform を実行するには必ず assume が必要になり、assume したときのみスコープ付きの権限が使われます。

- **初回のみ**: 管理者（PowerUserAccess + IAMFullAccessを持つ別の IAM ユーザー）が対象環境で `terraform apply` を実行し、ロールを作成する。各環境の `terraform.tfvars` で `terraform_runner_allow_assume_principal_arns` に、assume を許可する IAM ユーザーまたはロールの ARN のリストを設定する。
- **2 回目以降**: Terraform を実行する人は、**assume 用スクリプト**で一時クレデンシャルを取得してから `terraform plan` / `apply` を実行する。

**assume の手順**（リポジトリルートで実行）:

```bash
# dev 用ロールを assume し、現在のシェルに環境変数をセット
eval $(./scripts/assume-terraform-role.sh dev)
cd envs/dev && terraform plan
```

stg / prod の場合は `dev` を `stg` / `prod` に置き換えてください。スクリプトには AWS CLI と jq（または Python 3）が必要です。ロールが未作成の場合はスクリプトがエラーで終了します。

**Terraform 実行者に付与する assume 用ポリシー例**（PowerUserAccess の代わりにこのみ付与）:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [
        "arn:aws:iam::YOUR_ACCOUNT_ID:role/hbp-cc-dev-terraform-runner",
        "arn:aws:iam::YOUR_ACCOUNT_ID:role/hbp-cc-stg-terraform-runner",
        "arn:aws:iam::YOUR_ACCOUNT_ID:role/hbp-cc-prod-terraform-runner"
      ]
    }
  ]
}
```

`YOUR_ACCOUNT_ID` を実際の AWS アカウント ID に置き換えてください。ロール ARN は各環境で `terraform output terraform_runner_role_arn` でも確認できます。

### SSM Parameter Store

`envs/dev/main.tf` で `/hbp-cc/<env>/api-base-url` と `/hbp-cc/<env>/service-url` を作成するため、**ssm:PutParameter**（および運用で Get/Delete する場合は GetParameter, DeleteParameter）が必要です。権限不足の場合は次のようなエラーになります。

```text
AccessDeniedException: User: arn:aws:iam::ACCOUNT:user/USERNAME is not authorized to perform: ssm:PutParameter on resource: arn:aws:ssm:REGION:ACCOUNT:parameter/hbp-cc/dev/...
```


### RDS マスターパスワード（SSM のみ）

RDS のマスターパスワードは **SSM Parameter Store のみ**で参照します（`-var` での渡し方は廃止）。**環境ごと**にパスが決まります: `/hbp-cc/<env>/rds-master-password`（dev なら `/hbp-cc/dev/rds-master-password`、stg なら `/hbp-cc/stg/rds-master-password`）。別パスにしたいときだけ `db_password_ssm_parameter_name` を tfvars で指定する。

**初回のみ**: 対象環境の SSM に登録してから `terraform plan` / `apply` を実行する。

```bash
# dev の例
aws ssm put-parameter --name /hbp-cc/dev/rds-master-password --type SecureString --value 'あなたのパスワード' --region ap-northeast-1
```

パスワードは次の条件を満たすこと（満たさないと `Invalid master password`）。

- **長さ**: 8 文字以上 128 文字以下
- **使用不可文字**: 次の文字は含めないこと — `"`（ダブルクォート）, `` ` ``（バッククォート）, `\`, `@`, `/`, 半角スペース

英大文字・小文字・数字・記号（上記以外）を組み合わせた強めのパスワードを推奨します。

**本番（prod）での推奨**:

- **RDS**: `rds_deletion_protection = true` を tfvars で指定し、誤削除を防ぐ。
- **DB パスワードの渡し方**: ECS タスクには `db_password_secret_arn`（Secrets Manager の ARN）を渡し、`db_password_plain` は使わない。パスワードを Secrets Manager に登録し、その ARN を ECS モジュールの `db_password_secret_arn` に指定する。
- **JWT 等の秘密鍵**: `api_extra_environment` で平文を渡さず、SSM Parameter Store（SecureString）または Secrets Manager に格納し、ECS モジュールの `api_extra_secrets`（`{ name, valueFrom }` のリスト）と `api_extra_secret_arns`（タスク実行ロールに付与する ARN 一覧）で渡す。Terraform state に平文が残らない。

### SES 送信元メールアドレス

SES の送信元として使うメールアドレスは **環境ごとの tfvars** で指定します。

- **dev**: [envs/dev/terraform.tfvars](envs/dev/terraform.tfvars) の `ses_sender_email`（例: `dev-noreply@example.com`）
- **変数**: 各環境の `variables.tf` の `ses_sender_email` / `ses_domain`。どちらかが空でないときのみ SES モジュールが有効になる。

dev は SES サンドボックスのため、送信できるのは **検証済みの送信元アドレス** のみ。アドレスを変えた場合は、AWS コンソールの SES でそのアドレスを検証すること。

**SES だけデプロイする場合**（他リソースを立てずに SES のドメイン／メール検証だけ先行して行うとき）:

```bash
cd envs/dev
terraform plan -target=module.ses[0]
terraform apply -target=module.ses[0]
```

前提として、`/hbp-cc/dev/rds-master-password` が SSM に登録済みであること（plan 時にデータソースが参照するため）。SES モジュールは他モジュールに依存しないため、この target だけで作成できる。
