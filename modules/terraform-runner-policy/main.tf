# Terraform 実行用ロールにアタッチするポリシー（本リポジトリが作成するリソースの ARN に限定）。
# 環境ごとに env を渡すため、その環境のリソースのみ操作可能になる。

locals {
  prefix = "${var.project_name}-${var.env}"
  # リージョン・アカウントスコープ（EC2 系は ID が不定のため）
  ec2_scope = "arn:aws:ec2:${var.aws_region}:${var.account_id}:*"
  rds_scope = "arn:aws:rds:${var.aws_region}:${var.account_id}:*"
  ec_scope  = "arn:aws:elasticache:${var.aws_region}:${var.account_id}:*"
}

# 単一ポリシーが AWS 制限 6144 文字を超えるため、2 つに分割（権限は同一）
data "aws_iam_policy_document" "runner_core" {
  # STS
  statement {
    sid    = "STS"
    effect = "Allow"
    actions = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # SSM
  statement {
    sid    = "SSM"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/hbp-cc/${var.env}/*"]
  }

  # EC2
  statement {
    sid    = "EC2"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeAddresses",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:DescribeNatGateways",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes"
    ]
    resources = [local.ec2_scope]
  }

  # RDS
  statement {
    sid    = "RDS"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:DeleteDBInstance",
      "rds:ModifyDBInstance",
      "rds:DescribeDBInstances",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:ListTagsForResource"
    ]
    resources = [local.rds_scope]
  }

  # ElastiCache
  statement {
    sid    = "ElastiCache"
    effect = "Allow"
    actions = [
      "elasticache:CreateCacheCluster",
      "elasticache:DeleteCacheCluster",
      "elasticache:ModifyCacheCluster",
      "elasticache:DescribeCacheClusters",
      "elasticache:CreateCacheSubnetGroup",
      "elasticache:DeleteCacheSubnetGroup",
      "elasticache:DescribeCacheSubnetGroups",
      "elasticache:AddTagsToResource",
      "elasticache:RemoveTagsFromResource",
      "elasticache:ListTagsForResource"
    ]
    resources = [local.ec_scope]
  }

  # S3
  statement {
    sid    = "S3"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutBucketEncryption",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${local.prefix}-app",
      "arn:aws:s3:::${local.prefix}-app/*",
      "arn:aws:s3:::${local.prefix}-frontend",
      "arn:aws:s3:::${local.prefix}-frontend/*"
    ]
  }

  # IAM
  statement {
    sid    = "IAM"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.project_name}-*",
      "arn:aws:iam::${var.account_id}:policy/${var.project_name}-*",
      "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
    ]
  }

  # ECR
  statement {
    sid    = "ECR"
    effect = "Allow"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid    = "ECRRepository"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:PutLifecyclePolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:ListTagsForResource"
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${local.prefix}-*"]
  }
}

data "aws_iam_policy_document" "runner_app" {
  # ELB
  statement {
    sid    = "ELB"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["*"]
  }

  # ECS
  statement {
    sid    = "ECS"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:DescribeClusters",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions",
      "ecs:CreateService",
      "ecs:DeleteService",
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:ListServices",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:ListTagsForResource",
      "ecs:ExecuteCommand"
    ]
    resources = ["*"]
  }

  # ECS Exec (SSM Session Manager) - aws ecs execute-command 用
  statement {
    sid    = "SSMMessagesForECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  # CodeDeploy
  statement {
    sid    = "CodeDeploy"
    effect = "Allow"
    actions = [
      "codedeploy:CreateApplication",
      "codedeploy:DeleteApplication",
      "codedeploy:GetApplication",
      "codedeploy:CreateDeploymentGroup",
      "codedeploy:DeleteDeploymentGroup",
      "codedeploy:GetDeploymentGroup",
      "codedeploy:UpdateDeploymentGroup",
      "codedeploy:ListApplications",
      "codedeploy:ListDeploymentGroups",
      "codedeploy:TagResource",
      "codedeploy:UntagResource",
      "codedeploy:ListTagsForResource"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:ListTagsLogGroup"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/ecs/${local.prefix}-*"]
  }

  # CloudFront
  statement {
    sid    = "CloudFront"
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:ListDistributions",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:ListTagsForResource"
    ]
    resources = ["*"]
  }

  # SES
  statement {
    sid    = "SES"
    effect = "Allow"
    actions = [
      "ses:VerifyDomainIdentity",
      "ses:VerifyEmailIdentity",
      "ses:DeleteIdentity",
      "ses:GetIdentityVerificationAttributes",
      "ses:GetIdentityDkimAttributes",
      "ses:PutIdentityDkimAttributes"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "runner_core" {
  name        = "${local.prefix}-terraform-runner-core"
  description = "Terraform runner core (${var.env}): STS, SSM, EC2, RDS, ElastiCache, S3, IAM, ECR"
  policy      = data.aws_iam_policy_document.runner_core.json
  tags        = var.tags
}

resource "aws_iam_policy" "runner_app" {
  name        = "${local.prefix}-terraform-runner-app"
  description = "Terraform runner app (${var.env}): ELB, ECS, CodeDeploy, Logs, CloudFront, SES"
  policy      = data.aws_iam_policy_document.runner_app.json
  tags        = var.tags
}

# Terraform 実行用ロール（allow_assume_principal_arns が空でない場合のみ作成）
resource "aws_iam_role" "runner" {
  count = length(var.allow_assume_principal_arns) > 0 ? 1 : 0

  name = "${local.prefix}-terraform-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.allow_assume_principal_arns
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "runner_core" {
  count = length(var.allow_assume_principal_arns) > 0 ? 1 : 0

  role       = aws_iam_role.runner[0].name
  policy_arn = aws_iam_policy.runner_core.arn
}

resource "aws_iam_role_policy_attachment" "runner_app" {
  count = length(var.allow_assume_principal_arns) > 0 ? 1 : 0

  role       = aws_iam_role.runner[0].name
  policy_arn = aws_iam_policy.runner_app.arn
}
