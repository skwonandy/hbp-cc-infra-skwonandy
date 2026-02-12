#!/usr/bin/env bash
# S3 バケットを空にする（全オブジェクト・全バージョン・DeleteMarker削除）と
# ECR リポジトリ内の全イメージを削除するスクリプト。
# Terraform destroy で BucketNotEmpty / RepositoryNotEmptyException が出る場合に実行し、
# その後 terraform destroy を再実行する。
#
# 使い方:
#   eval $(./scripts/assume-terraform-role.sh dev)   # 必要に応じて
#   ./scripts/empty-s3-and-ecr.sh dev               # env 指定で HBP の dev 用バケット・ECR を対象
#   ./scripts/empty-s3-and-ecr.sh dev --bucket hbp-cc-dev-frontend  # 特定バケットのみ
#   ./scripts/empty-s3-and-ecr.sh dev --ecr hbp-cc-dev-api          # 特定 ECR のみ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# デフォルト
PROJECT_NAME="${PROJECT_NAME:-hbp-cc}"

usage() {
  echo "Usage: $0 ENV [OPTIONS]" >&2
  echo "  ENV: dev | stg | prod" >&2
  echo "  OPTIONS:" >&2
  echo "    --bucket NAME  対象 S3 バケットを 1 つ指定（複数回可）。未指定時は env から推論した全バケット。" >&2
  echo "    --ecr NAME     対象 ECR リポジトリを 1 つ指定（複数回可）。未指定時は env から推論した api/worker。" >&2
  echo "    --dry-run      削除せずに対象のみ表示" >&2
  exit 1
}

ENV=""
BUCKETS=()
ECR_REPOS=()
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    dev|stg|prod)
      ENV="$1"
      shift
      ;;
    --bucket)
      BUCKETS+=("$2")
      shift 2
      ;;
    --ecr)
      ECR_REPOS+=("$2")
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "Error: ENV (dev|stg|prod) is required." >&2
  usage
fi

# 対象が未指定なら env から推論
if [[ ${#BUCKETS[@]} -eq 0 ]]; then
  BUCKETS=(
    "${PROJECT_NAME}-${ENV}-app"
    "${PROJECT_NAME}-${ENV}-frontend"
    "${PROJECT_NAME}-${ENV}-resources"
  )
fi
if [[ ${#ECR_REPOS[@]} -eq 0 ]]; then
  ECR_REPOS=(
    "${PROJECT_NAME}-${ENV}-api"
    "${PROJECT_NAME}-${ENV}-worker"
  )
fi

empty_s3_bucket() {
  local bucket="$1"
  if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "[S3] Bucket $bucket does not exist, skip."
    return 0
  fi

  echo "[S3] Emptying bucket: $bucket"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  (dry-run: would delete all versions and delete markers)"
    return 0
  fi

  local total=0
  local next_key="" next_ver=""
  while true; do
    local json
    if [[ -n "$next_key" || -n "$next_ver" ]]; then
      json="$(aws s3api list-object-versions --bucket "$bucket" --key-marker "$next_key" --version-id-marker "$next_ver" --max-items 1000)" || true
    else
      json="$(aws s3api list-object-versions --bucket "$bucket" --max-items 1000)" || true
    fi

    # Versions と DeleteMarkers をまとめて Objects 配列にし、delete-objects で一括削除（最大1000件/回）
    local objects
    objects="$(echo "$json" | jq -c '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key: .Key, VersionId: .VersionId})), Quiet: true}' 2>/dev/null)" || true
    local n
    n="$(echo "$objects" | jq '.Objects | length')"
    if [[ "$n" -gt 0 ]]; then
      aws s3api delete-objects --bucket "$bucket" --delete "$objects" --output text >/dev/null
      total=$(( total + n ))
    fi

    next_key="$(echo "$json" | jq -r '.NextKeyMarker // empty')"
    next_ver="$(echo "$json" | jq -r '.NextVersionIdMarker // empty')"
    if [[ -z "$next_key" && -z "$next_ver" ]]; then
      break
    fi
  done

  echo "[S3] Emptied $bucket (deleted $total objects/versions)."
}

empty_ecr_repository() {
  local repo="$1"
  if ! aws ecr describe-repositories --repository-names "$repo" &>/dev/null; then
    echo "[ECR] Repository $repo does not exist, skip."
    return 0
  fi

  echo "[ECR] Emptying repository: $repo"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  (dry-run: would delete all images)"
    return 0
  fi

  local count=0
  while true; do
    local ids
    ids="$(aws ecr list-images --repository-name "$repo" --query 'imageIds[*]' --output json 2>/dev/null)" || true
    if [[ "$ids" == "[]" || -z "$ids" ]]; then
      break
    fi
    # CLI は imageDigest=... imageTag=... の形式で受け付ける
    local args
    args="$(echo "$ids" | jq -r '.[] | "imageDigest=" + .imageDigest + (if .imageTag then " imageTag=" + .imageTag else "" end)' | tr '\n' ' ')"
    aws ecr batch-delete-image --repository-name "$repo" --image-ids $args --output text >/dev/null
    count=$(( count + $(echo "$ids" | jq length) ))
  done
  echo "[ECR] Emptied $repo (deleted $count image(s))."
}

# jq 必須（list-object-versions のパースに使用）
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install jq and retry." >&2
  exit 1
fi

echo "Target S3 buckets: ${BUCKETS[*]}"
echo "Target ECR repos: ${ECR_REPOS[*]}"
if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN - no changes will be made."
fi
echo ""

for b in "${BUCKETS[@]}"; do
  empty_s3_bucket "$b"
done
for r in "${ECR_REPOS[@]}"; do
  empty_ecr_repository "$r"
done

echo ""
echo "Done. You can run: terraform -chdir=envs/$ENV destroy"
