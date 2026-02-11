# hbp-cc-infra

hbp-cc アプリケーションの AWS インフラを Terraform で管理する **専用リポジトリ**。環境は sandbox / dev / stg / prod。差異はサイズ（tfvars）のみ。

## 前提

- Terraform 1.14.4
- AWS CLI 設定済み（または環境変数 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`）
- 各環境の `backend.tf` は初期状態で **local** バックエンド。S3 バックエンドに切り替える場合は、バケットと DynamoDB テーブル作成後に `backend.tf` のコメントを入れ替え、`terraform init -reconfigure` を実行する

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

ポリシーを JSON で作成してから、指定ユーザーにアタッチする例です（`YOUR_ACCOUNT_ID` と `ap-northeast-1` を必要に応じて置き換え、`janscore` をアタッチ先の IAM ユーザー名に変更してください）。

```bash
# 1. ポリシーを作成（上記 JSON を policy.json として保存してから）
aws iam create-policy \
  --policy-name hbp-cc-dev-terraform-runner-ssm \
  --policy-document file://policy.json

# 2. 作成したポリシーを IAM ユーザーにアタッチ
aws iam attach-user-policy \
  --user-name janscore \
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
