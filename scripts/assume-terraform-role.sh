#!/usr/bin/env bash
# Terraform 実行用ロールを assume し、環境変数 AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN を出力する。
# 使い方: eval $(./scripts/assume-terraform-role.sh dev)
# 実行後、同じシェルで cd envs/dev && terraform plan などを行う。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV="${1:-}"
if [[ "$ENV" != "dev" && "$ENV" != "stg" && "$ENV" != "prod" ]]; then
  echo "Usage: eval \$($0 dev|stg|prod)" >&2
  echo "  dev, stg, prod のいずれかを指定してください。" >&2
  exit 1
fi

ROLE_ARN=""
ROLE_ARN="$(cd "$REPO_ROOT" && terraform -chdir="envs/$ENV" output -raw terraform_runner_role_arn 2>/dev/null)" || true
if [[ -z "$ROLE_ARN" || "$ROLE_ARN" == "null" ]]; then
  echo "Error: Terraform runner role for env '$ENV' is not created yet. Run 'terraform apply' in envs/$ENV with broad permissions first, and set terraform_runner_allow_assume_principal_arns in terraform.tfvars." >&2
  exit 1
fi

SESSION_NAME="terraform-${ENV}"
CREDS="$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME" --query 'Credentials' --output json)"
if [[ -z "$CREDS" ]]; then
  echo "Error: Failed to assume role $ROLE_ARN" >&2
  exit 1
fi

# eval で実行する export 文を出力
if command -v jq &>/dev/null; then
  echo "$CREDS" | jq -r '
    "export AWS_ACCESS_KEY_ID=" + .AccessKeyId,
    "export AWS_SECRET_ACCESS_KEY=" + .SecretAccessKey,
    "export AWS_SESSION_TOKEN=" + .SessionToken
  '
else
  python3 -c "
import json, sys
d = json.load(sys.stdin)
print('export AWS_ACCESS_KEY_ID=' + d['AccessKeyId'])
print('export AWS_SECRET_ACCESS_KEY=' + d['SecretAccessKey'])
print('export AWS_SESSION_TOKEN=' + d['SessionToken'])
" <<< "$CREDS"
fi
