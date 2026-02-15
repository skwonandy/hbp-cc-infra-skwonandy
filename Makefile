# hbp-cc-infra 汎用 Makefile
# 環境: ENV=dev|stg|prod。例: make plan ENV=dev

ENV ?= dev
TF_DIR := envs/$(ENV)
AWS_REGION ?= ap-northeast-1

.DEFAULT_GOAL := help
.PHONY: help init plan apply apply-acm-cert destroy validate fmt output \
        bootstrap assume ecs-exec ecs-logs \
        plan-target apply-target \
        cf-invalidate urls deploy-role ses-status

help:
	@echo "Usage: make [target] [ENV=dev|stg|prod]"
	@echo ""
	@echo "--- 基本操作 ---"
	@echo "  help            このヘルプを表示"
	@echo "  init            terraform init ($(TF_DIR))"
	@echo "  plan            terraform plan（事前に ACM 証明書を apply）"
	@echo "  apply           terraform apply（事前に ACM 証明書を apply）"
	@echo "  destroy         S3/ECR を空にしてから terraform destroy"
	@echo "  validate        terraform validate"
	@echo "  fmt             terraform fmt -recursive"
	@echo "  output          terraform output（VAR=name で特定出力のみ）"
	@echo ""
	@echo "--- 初回セットアップ ---"
	@echo "  bootstrap       リモートステート用 S3/DynamoDB を作成（初回のみ）"
	@echo "  assume          Terraform 実行用ロールの assume コマンドを表示"
	@echo ""
	@echo "--- ターゲット指定 ---"
	@echo "  plan-target     特定モジュールのみ plan   TARGET=module.ses[0]"
	@echo "  apply-target    特定モジュールのみ apply  TARGET=module.ses[0]"
	@echo "  apply-acm-cert  ACM 証明書のみ先に作成（plan/apply に統合済み）"
	@echo ""
	@echo "--- ECS / 運用 ---"
	@echo "  ecs-exec        SSM で ECS タスクにログイン（インタラクティブシェル）"
	@echo "  ecs-logs        ECS API の CloudWatch Logs を tail（直近 10 分）"
	@echo ""
	@echo "--- 確認・ユーティリティ ---"
	@echo "  urls            フロントエンド・API の URL を表示"
	@echo "  deploy-role     GitHub Actions 用デプロイロール ARN を表示"
	@echo "  cf-invalidate   CloudFront キャッシュを全無効化"
	@echo "  ses-status      既存 SES ドメインの検証ステータスを表示"
	@echo ""
	@echo "例: make plan ENV=stg"
	@echo "    make apply-target TARGET=module.ecs ENV=dev"
	@echo "    make output VAR=frontend_url"

# ==============================================================================
# 基本操作
# ==============================================================================

init:
	terraform -chdir=$(TF_DIR) init

plan: init apply-acm-cert
	terraform -chdir=$(TF_DIR) plan

apply: init apply-acm-cert
	terraform -chdir=$(TF_DIR) apply

validate:
	terraform -chdir=$(TF_DIR) validate

fmt:
	terraform fmt -recursive

# output: 全出力。VAR=github_actions_deploy_role_arn で 1 件のみ
output:
ifdef VAR
	terraform -chdir=$(TF_DIR) output -raw $(VAR)
else
	terraform -chdir=$(TF_DIR) output
endif

# S3/ECR を空にしてから terraform destroy（BucketNotEmpty / RepositoryNotEmptyException 対策）
destroy:
	./scripts/empty-s3-and-ecr.sh $(ENV)
	terraform -chdir=$(TF_DIR) destroy

# ==============================================================================
# 初回セットアップ
# ==============================================================================

# リモートステート用 S3 バケット・DynamoDB テーブルを作成（初回のみ）
bootstrap:
	terraform -chdir=bootstrap init
	terraform -chdir=bootstrap apply

# Terraform 実行用ロールの assume コマンドを表示（Make 内では export できないため表示のみ）
assume:
	@echo "以下を実行して Terraform 実行用ロールを assume してください:"
	@echo ""
	@echo '  eval $$(./scripts/assume-terraform-role.sh $(ENV))'
	@echo ""

# ==============================================================================
# ターゲット指定
# ==============================================================================

# ACM 証明書を先に作成する。証明書が無い状態だと plan で for_each が不定になりエラーになるため、plan/apply の前に自動実行される。
apply-acm-cert: init
	terraform -chdir=$(TF_DIR) apply -target=module.acm[0].aws_acm_certificate.main -auto-approve

# 特定モジュールのみ plan。例: make plan-target TARGET=module.ecs
plan-target: init
ifndef TARGET
	$(error TARGET is required. Example: make plan-target TARGET=module.ecs)
endif
	terraform -chdir=$(TF_DIR) plan -target=$(TARGET)

# 特定モジュールのみ apply。例: make apply-target TARGET=module.ses[0]
apply-target: init
ifndef TARGET
	$(error TARGET is required. Example: make apply-target TARGET=module.ses[0])
endif
	terraform -chdir=$(TF_DIR) apply -target=$(TARGET)

# ==============================================================================
# ECS / 運用
# ==============================================================================

# SSM（ECS Exec）で実行中タスクのコンテナにログイン。Session Manager プラグイン必須。
ecs-exec:
	@CLUSTER=$$(terraform -chdir=$(TF_DIR) output -raw ecs_cluster_name); \
	SERVICE=$$(terraform -chdir=$(TF_DIR) output -raw ecs_service_name); \
	TASK_ARN=$$(aws ecs list-tasks --cluster "$$CLUSTER" --service-name "$$SERVICE" --desired-status RUNNING --query 'taskArns[0]' --output text --region $(AWS_REGION)); \
	TASK_ID=$${TASK_ARN##*/}; \
	aws ecs execute-command --cluster "$$CLUSTER" --task "$$TASK_ID" --container api --interactive --command "/bin/sh" --region $(AWS_REGION)

# ECS API の CloudWatch Logs を tail（直近 10 分、Ctrl+C で停止）
ecs-logs:
	@echo "Tailing /ecs/hbp-cc-$(ENV)-api ..."
	aws logs tail /ecs/hbp-cc-$(ENV)-api --since 10m --follow --region $(AWS_REGION)

# ==============================================================================
# 確認・ユーティリティ
# ==============================================================================

# フロントエンド・API の URL を表示
urls:
	@echo "Frontend URL:"
	@terraform -chdir=$(TF_DIR) output -raw frontend_url 2>/dev/null || echo "  (not yet applied)"
	@echo ""
	@echo "API URL (ALB direct):"
	@terraform -chdir=$(TF_DIR) output -raw api_url 2>/dev/null || echo "  (not yet applied)"
	@echo ""

# GitHub Actions 用デプロイロール ARN を表示
deploy-role:
	@terraform -chdir=$(TF_DIR) output -raw github_actions_deploy_role_arn

# CloudFront キャッシュを全無効化（/* パス）
cf-invalidate:
	@DIST_ID=$$(terraform -chdir=$(TF_DIR) output -raw cloudfront_distribution_id); \
	echo "Invalidating CloudFront distribution: $$DIST_ID ..."; \
	aws cloudfront create-invalidation --distribution-id "$$DIST_ID" --paths "/*" --region $(AWS_REGION)

# 既存 SES ドメインの検証ステータスを表示（Terraform 管理外の参照用）
ses-status:
	@SES_REGION=$$(grep -oP 'ses_existing_region\s*=\s*"\K[^"]+' $(TF_DIR)/terraform.tfvars 2>/dev/null); \
	SES_DOMAIN=$$(grep -oP 'ses_existing_domain\s*=\s*"\K[^"]+' $(TF_DIR)/terraform.tfvars 2>/dev/null); \
	if [ -z "$$SES_DOMAIN" ] || [ -z "$$SES_REGION" ]; then \
	  echo "ses_existing_domain / ses_existing_region が $(TF_DIR)/terraform.tfvars に未設定です"; \
	  exit 1; \
	fi; \
	echo "=== SES Identity: $$SES_DOMAIN ($$SES_REGION) ==="; \
	echo ""; \
	echo "--- Verification ---"; \
	aws ses get-identity-verification-attributes --identities "$$SES_DOMAIN" --region "$$SES_REGION"; \
	echo ""; \
	echo "--- DKIM ---"; \
	aws ses get-identity-dkim-attributes --identities "$$SES_DOMAIN" --region "$$SES_REGION"; \
	echo ""; \
	echo "--- Account ---"; \
	aws sesv2 get-account --region "$$SES_REGION" --query '{ProductionAccess:ProductionAccessEnabled,SendingEnabled:SendingEnabled,SendQuota:SendQuota}'
