# CICD モジュール

**ECR**: API / worker / frontend 用リポジトリを環境ごとに作成する（`modules/cicd` の main.tf で定義）。`create_worker_repository` が `false` のときは worker 用 ECR を作成しない（dev 環境等で使用）。push 時イメージスキャン有効。

**GitHub OIDC**: `github_org_repo` 指定時、デプロイ用 IAM ロール（ECR push + S3 frontend 同期）を作成。OIDC プロバイダは `create_oidc_provider=true` の環境で 1 回だけ作成し、他環境は data で参照。output `github_actions_deploy_role_arn` を GitHub Environment の `AWS_DEPLOY_ROLE_ARN` に登録する。
