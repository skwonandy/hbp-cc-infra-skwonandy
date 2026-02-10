# ECR リポジトリ（API / worker / frontend）。GitHub OIDC 用 IAM ロールは github_org_repo 指定時のみ作成。

# --- GitHub OIDC（アカウントで1つ。create_oidc_provider=true の環境で作成、他は data で参照）---
data "aws_caller_identity" "current" {
  count = var.github_org_repo != "" ? 1 : 0
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_org_repo != "" && var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.github_org_repo != "" && !var.create_oidc_provider ? 1 : 0

  arn = "arn:aws:iam::${data.aws_caller_identity.current[0].account_id}:oidc-provider/token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.github_org_repo != "" ? (var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn) : null
}

# --- デプロイ用 IAM ロール（GitHub Actions が assume、ECR push + S3 frontend 同期）---
resource "aws_iam_role" "github_actions_deploy" {
  count = var.github_org_repo != "" ? 1 : 0

  name = "${var.project_name}-github-deploy-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org_repo}:environment:${var.env}"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-github-deploy-${var.env}"
  })
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  count = var.github_org_repo != "" ? 1 : 0

  name = "ecr-s3-deploy"
  role = aws_iam_role.github_actions_deploy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "ECRAuth"
          Effect = "Allow"
          Action = "ecr:GetAuthorizationToken"
          Resource = "*"
        },
        {
          Sid    = "ECRApiPush"
          Effect = "Allow"
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload"
          ]
          Resource = aws_ecr_repository.api.arn
        },
        {
          Sid      = "S3FrontendSync"
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
          Resource = [
            "arn:aws:s3:::${var.project_name}-${var.env}-frontend",
            "arn:aws:s3:::${var.project_name}-${var.env}-frontend/*"
          ]
        },
        {
          Sid    = "ECSForCodeDeploy"
          Effect = "Allow"
          Action = [
            "ecs:DescribeServices",
            "ecs:DescribeTaskDefinition",
            "ecs:RegisterTaskDefinition",
            "ecs:ListTaskDefinitions"
          ]
          Resource = "*"
        },
        {
          Sid    = "IamPassRoleForEcs"
          Effect = "Allow"
          Action = "iam:PassRole"
          Resource = "*"
          Condition = {
            StringLike = {
              "iam:PassedToService" = "ecs-tasks.amazonaws.com"
            }
          }
        },
        {
          Sid    = "CodeDeploy"
          Effect = "Allow"
          Action = [
            "codedeploy:CreateDeployment",
            "codedeploy:GetDeployment",
            "codedeploy:GetDeploymentConfig",
            "codedeploy:GetApplication",
            "codedeploy:GetApplicationRevision",
            "codedeploy:RegisterApplicationRevision",
            "codedeploy:GetDeploymentGroup",
            "codedeploy:ListDeployments",
            "codedeploy:StopDeployment"
          ]
          Resource = "*"
        },
        {
          Sid    = "CloudFrontInvalidation"
          Effect = "Allow"
          Action = [
            "cloudfront:CreateInvalidation",
            "cloudfront:GetDistribution"
          ]
          Resource = "*"
        }
      ],
      var.create_worker_repository ? [
        {
          Sid    = "ECRWorkerPush"
          Effect = "Allow"
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload"
          ]
          Resource = aws_ecr_repository.worker[0].arn
        }
      ] : []
    )
  })
}

# --- ECR リポジトリ ---
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.env}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-api"
  })
}

resource "aws_ecr_repository" "worker" {
  count = var.create_worker_repository ? 1 : 0

  name                 = "${var.project_name}-${var.env}-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-worker"
  })
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-${var.env}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-frontend"
  })
}
