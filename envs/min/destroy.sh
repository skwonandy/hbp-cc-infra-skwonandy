#!/bin/bash
# min 環境の完全破棄スクリプト
# ECR と S3 を空にしてから Terraform destroy を実行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV="min"
PROJECT="hbp-cc"
REGION="ap-northeast-1"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}min 環境の破棄を開始します${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# RDS パスワードの確認
if [ -z "$TF_VAR_db_password" ]; then
  echo -e "${RED}エラー: TF_VAR_db_password が設定されていません${NC}"
  echo "export TF_VAR_db_password='your-password' を実行してください"
  exit 1
fi

# 確認プロンプト
echo -e "${RED}警告: この操作は以下のリソースを完全に削除します:${NC}"
echo "  - VPC / サブネット / セキュリティグループ"
echo "  - RDS（PostgreSQL）"
echo "  - ElastiCache（Redis）"
echo "  - S3 バケット（すべてのオブジェクトを含む）"
echo "  - ECR リポジトリ（すべてのイメージを含む）"
echo "  - ALB / ECS / CodeDeploy / CloudFront"
echo "  - IAM ロール"
echo ""
read -p "本当に削除しますか？ (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "キャンセルしました"
  exit 0
fi

echo ""
echo -e "${GREEN}Step 1: S3 バケットのクリーンアップ${NC}"

# S3 frontend バケット
FRONTEND_BUCKET="${PROJECT}-${ENV}-frontend"
echo "S3 バケット: $FRONTEND_BUCKET を空にします..."

if aws s3api head-bucket --bucket "$FRONTEND_BUCKET" --region "$REGION" 2>/dev/null; then
  echo "  - オブジェクトを削除中..."
  aws s3 rm "s3://$FRONTEND_BUCKET" --recursive --region "$REGION" 2>/dev/null || true
  
  echo "  - バージョンを削除中..."
  VERSIONS=$(aws s3api list-object-versions \
    --bucket "$FRONTEND_BUCKET" \
    --region "$REGION" \
    --output json \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{"Objects":[]}')
  
  if [ "$(echo "$VERSIONS" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('Objects', [])))")" -gt 0 ]; then
    echo "$VERSIONS" | aws s3api delete-objects \
      --bucket "$FRONTEND_BUCKET" \
      --delete "file:///dev/stdin" \
      --region "$REGION" >/dev/null 2>&1 || true
  fi
  
  echo "  - 削除マーカーを削除中..."
  DELETE_MARKERS=$(aws s3api list-object-versions \
    --bucket "$FRONTEND_BUCKET" \
    --region "$REGION" \
    --output json \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{"Objects":[]}')
  
  if [ "$(echo "$DELETE_MARKERS" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('Objects', [])))")" -gt 0 ]; then
    echo "$DELETE_MARKERS" | aws s3api delete-objects \
      --bucket "$FRONTEND_BUCKET" \
      --delete "file:///dev/stdin" \
      --region "$REGION" >/dev/null 2>&1 || true
  fi
  
  echo -e "${GREEN}  ✓ $FRONTEND_BUCKET を空にしました${NC}"
else
  echo "  - $FRONTEND_BUCKET は存在しません（スキップ）"
fi

# S3 app バケット
APP_BUCKET="${PROJECT}-${ENV}-app"
echo "S3 バケット: $APP_BUCKET を空にします..."

if aws s3api head-bucket --bucket "$APP_BUCKET" --region "$REGION" 2>/dev/null; then
  echo "  - オブジェクトを削除中..."
  aws s3 rm "s3://$APP_BUCKET" --recursive --region "$REGION" 2>/dev/null || true
  
  echo "  - バージョンを削除中..."
  VERSIONS=$(aws s3api list-object-versions \
    --bucket "$APP_BUCKET" \
    --region "$REGION" \
    --output json \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{"Objects":[]}')
  
  if [ "$(echo "$VERSIONS" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('Objects', [])))")" -gt 0 ]; then
    echo "$VERSIONS" | aws s3api delete-objects \
      --bucket "$APP_BUCKET" \
      --delete "file:///dev/stdin" \
      --region "$REGION" >/dev/null 2>&1 || true
  fi
  
  echo "  - 削除マーカーを削除中..."
  DELETE_MARKERS=$(aws s3api list-object-versions \
    --bucket "$APP_BUCKET" \
    --region "$REGION" \
    --output json \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null || echo '{"Objects":[]}')
  
  if [ "$(echo "$DELETE_MARKERS" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('Objects', [])))")" -gt 0 ]; then
    echo "$DELETE_MARKERS" | aws s3api delete-objects \
      --bucket "$APP_BUCKET" \
      --delete "file:///dev/stdin" \
      --region "$REGION" >/dev/null 2>&1 || true
  fi
  
  echo -e "${GREEN}  ✓ $APP_BUCKET を空にしました${NC}"
else
  echo "  - $APP_BUCKET は存在しません（スキップ）"
fi

echo ""
echo -e "${GREEN}Step 2: ECR リポジトリのクリーンアップ${NC}"

# ECR API リポジトリ
API_REPO="${PROJECT}-${ENV}-api"
echo "ECR リポジトリ: $API_REPO のイメージを削除します..."

if aws ecr describe-repositories --repository-names "$API_REPO" --region "$REGION" >/dev/null 2>&1; then
  IMAGE_IDS=$(aws ecr list-images \
    --repository-name "$API_REPO" \
    --region "$REGION" \
    --output json \
    --query 'imageIds' 2>/dev/null || echo '[]')
  
  IMAGE_COUNT=$(echo "$IMAGE_IDS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  
  if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo "  - $IMAGE_COUNT 個のイメージを削除中..."
    echo "$IMAGE_IDS" | aws ecr batch-delete-image \
      --repository-name "$API_REPO" \
      --image-ids "file:///dev/stdin" \
      --region "$REGION" >/dev/null 2>&1 || true
    echo -e "${GREEN}  ✓ $API_REPO のイメージを削除しました${NC}"
  else
    echo "  - $API_REPO にイメージはありません（スキップ）"
  fi
else
  echo "  - $API_REPO は存在しません（スキップ）"
fi

# ECR Frontend リポジトリ
FRONTEND_REPO="${PROJECT}-${ENV}-frontend"
echo "ECR リポジトリ: $FRONTEND_REPO のイメージを削除します..."

if aws ecr describe-repositories --repository-names "$FRONTEND_REPO" --region "$REGION" >/dev/null 2>&1; then
  IMAGE_IDS=$(aws ecr list-images \
    --repository-name "$FRONTEND_REPO" \
    --region "$REGION" \
    --output json \
    --query 'imageIds' 2>/dev/null || echo '[]')
  
  IMAGE_COUNT=$(echo "$IMAGE_IDS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  
  if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo "  - $IMAGE_COUNT 個のイメージを削除中..."
    echo "$IMAGE_IDS" | aws ecr batch-delete-image \
      --repository-name "$FRONTEND_REPO" \
      --image-ids "file:///dev/stdin" \
      --region "$REGION" >/dev/null 2>&1 || true
    echo -e "${GREEN}  ✓ $FRONTEND_REPO のイメージを削除しました${NC}"
  else
    echo "  - $FRONTEND_REPO にイメージはありません（スキップ）"
  fi
else
  echo "  - $FRONTEND_REPO は存在しません（スキップ）"
fi

echo ""
echo -e "${GREEN}Step 3: Terraform destroy 実行${NC}"

terraform destroy -auto-approve

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}min 環境の破棄が完了しました！${NC}"
echo -e "${GREEN}========================================${NC}"
