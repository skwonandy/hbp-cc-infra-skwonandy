# hbp-cc-infra

hbp-cc アプリケーションの AWS インフラを Terraform で管理する **専用リポジトリ**。環境は sandbox / dev / stg / prod。差異はサイズ（tfvars）のみ。

## 前提

- Terraform 1.14.4
- AWS CLI 設定済み（または環境変数 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`）

### GitHub Actions と OIDC

アプリリポジトリ（hbp-cc-skwonandy）のデプロイ workflow は、**GitHub Environment 名が Terraform の env（dev / stg / prod）と一致している必要があります**。リポジトリの Settings → Environments で **dev** / **stg** / **prod** の 3 つを作成し、各 Environment の Secrets に **`AWS_DEPLOY_ROLE_ARN`** のみ登録してください。CloudFront のキャッシュ無効化用の Distribution ID は、workflow 内で環境名（`hbp-cc-<env> frontend` の Comment）から自動取得するため、別途登録は不要です。ブランチ名は development / staging / production のままでよく、workflow 内で dev / stg / prod にマッピングされます。

## Terraform 実行に必要な IAM 権限

`terraform apply` を実行する IAM ユーザー／ロールには、本リポジトリが作成するリソース用の権限に加え、少なくとも以下が必要です。

### SSM Parameter Store

`envs/dev/main.tf` で `/hbp-cc/<env>/api-base-url` と `/hbp-cc/<env>/service-url` を作成するため、**ssm:PutParameter**（および運用で Get/Delete する場合は GetParameter, DeleteParameter）が必要です。権限不足の場合は次のようなエラーになります。

```text
AccessDeniedException: User: arn:aws:iam::ACCOUNT:user/USERNAME is not authorized to perform: ssm:PutParameter on resource: arn:aws:ssm:REGION:ACCOUNT:parameter/hbp-cc/dev/...
```

**例: 最小限のインラインポリシー（dev で SSM パラメータを作成する場合）**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:DeleteParameter",
        "ssm:AddTagsToResource"
      ],
      "Resource": "arn:aws:ssm:ap-northeast-1:YOUR_ACCOUNT_ID:parameter/hbp-cc/dev/*"
    }
  ]
}
```

`YOUR_ACCOUNT_ID` を実際の AWS アカウント ID に、リージョンが ap-northeast-1 でない場合は `ap-northeast-1` を該当リージョンに置き換えてください。他の環境（stg/prod）でも SSM を使う場合は、同様に `parameter/hbp-cc/stg/*` などを追加してください。

**AWS CLI で直接アタッチする場合**

ポリシーを JSON で作成してから、指定ユーザーにアタッチする例です（`YOUR_ACCOUNT_ID` と `ap-northeast-1` を必要に応じて置き換え、`YOUR_IAM_USER` をアタッチ先の IAM ユーザー名に変更してください）。

```bash
# 1. ポリシーを作成（上記 JSON を policy.json として保存してから）
aws iam create-policy \
  --policy-name hbp-cc-dev-terraform-runner-ssm \
  --policy-document file://policy.json

# 2. 作成したポリシーを IAM ユーザーにアタッチ
aws iam attach-user-policy \
  --user-name YOUR_IAM_USER \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/hbp-cc-dev-terraform-runner-ssm
```

既に同名ポリシーが存在する場合は、上記の 2 だけを実行すればよいです。

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
