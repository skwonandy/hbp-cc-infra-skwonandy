# hbp-cc-infra 汎用 Makefile
# 環境: ENV=dev|stg|prod。例: make plan ENV=dev

ENV ?= dev
TF_DIR := envs/$(ENV)
AWS_REGION ?= ap-northeast-1

.DEFAULT_GOAL := help
.PHONY: help init plan apply destroy validate fmt output ecs-exec

help:
	@echo "Usage: make [target] [ENV=dev|stg|prod]"
	@echo ""
	@echo "Targets:"
	@echo "  help         - このヘルプを表示"
	@echo "  init         - terraform init ($(TF_DIR))"
	@echo "  plan         - terraform plan"
	@echo "  apply        - terraform apply"
	@echo "  destroy      - S3/ECR を空にしてから terraform destroy"
	@echo "  ecs-exec     - SSM で ECS タスクにログイン（インタラクティブシェル）"
	@echo "  validate     - terraform validate"
	@echo "  fmt          - terraform fmt -recursive"
	@echo "  output       - terraform output（VAR=name で特定出力のみ）"
	@echo ""
	@echo "例: make plan ENV=stg   # stg で plan"

init:
	terraform -chdir=$(TF_DIR) init

plan: init
	terraform -chdir=$(TF_DIR) plan

apply: init
	terraform -chdir=$(TF_DIR) apply

# SSM（ECS Exec）で実行中タスクのコンテナにログイン。Session Manager プラグイン必須。
ecs-exec:
	@CLUSTER=$$(terraform -chdir=$(TF_DIR) output -raw ecs_cluster_name); \
	SERVICE=$$(terraform -chdir=$(TF_DIR) output -raw ecs_service_name); \
	TASK_ARN=$$(aws ecs list-tasks --cluster "$$CLUSTER" --service-name "$$SERVICE" --desired-status RUNNING --query 'taskArns[0]' --output text --region $(AWS_REGION)); \
	TASK_ID=$${TASK_ARN##*/}; \
	aws ecs execute-command --cluster "$$CLUSTER" --task "$$TASK_ID" --container api --interactive --command "/bin/sh" --region $(AWS_REGION)

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
