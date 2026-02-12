# ECS クラスタ、FastAPI 用サービス。Rolling デプロイ、ECS Exec 任意。

locals {
  name_prefix     = "${var.project_name}-${var.env}"
  container_name  = "api"
  container_port  = var.container_port
}

# --- ECS クラスタ ---
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

# --- タスク実行ロール（ECR pull, CloudWatch Logs）---
resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_ecr" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SERVICE_URL を SSM から取得する場合のタスク実行ロール権限（count は plan 時確定の use_service_url_ssm で制御）
resource "aws_iam_role_policy" "task_execution_ssm_service_url" {
  count = var.use_service_url_ssm ? 1 : 0

  name   = "ssm-service-url"
  role   = aws_iam_role.task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters"]
        Resource = [var.service_url_ssm_arn]
      }
    ]
  })
}

# api_extra_secrets 用（SSM / Secrets Manager の ARN を読む権限）
resource "aws_iam_role_policy" "task_execution_extra_secrets" {
  count = length(var.api_extra_secret_arns) > 0 ? 1 : 0

  name   = "extra-secrets"
  role   = aws_iam_role.task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters"]
        Resource = var.api_extra_secret_arns
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.api_extra_secret_arns
      }
    ]
  })
}

# --- タスクロール（S3 アプリバケット等）---
resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "task_s3" {
  name = "s3-app-bucket"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_app_bucket}",
          "arn:aws:s3:::${var.s3_app_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "task_ses" {
  count = var.attach_ses_policy ? 1 : 0

  name = "ses-send"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = var.ses_identity_arns
      }
    ]
  })
}

# enable_execute_command が true のとき、タスクロールに ECS Exec（SSM Session Manager）用の権限を付与
resource "aws_iam_role_policy" "task_ecs_exec" {
  count = var.enable_execute_command ? 1 : 0

  name   = "ecs-exec-ssmmessages"
  role   = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- ECS 用 SG（ALB からの container_port のみ許可）---
resource "aws_security_group" "ecs" {
  name_prefix = "${local.name_prefix}-ecs-"
  description = "ECS API - allow from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "API from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --- CloudWatch Logs ---
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

locals {
  api_env = concat(
    [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_user },
      { name = "REDIS_HOST", value = var.redis_host },
      { name = "AWS_S3_TEMPORARY_BUCKET_NAME", value = var.s3_app_bucket },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "ENV", value = var.app_env },
    ],
    var.use_service_url_ssm ? [] : [{ name = "SERVICE_URL", value = var.service_url }],
    [
      { name = "DB_POOL_SIZE", value = tostring(var.db_pool_size) },
      { name = "DB_HOST_REPLICATIONS", value = var.db_host_replications },
      { name = "SENTRY_DSN", value = var.sentry_dsn },
    ],
    var.db_password_secret_arn == "" && var.db_password_plain != null ? [{ name = "DB_PASSWORD", value = var.db_password_plain }] : [],
    var.api_extra_environment
  )
  api_secrets = concat(
    var.db_password_secret_arn != "" ? [{ name = "DB_PASSWORD", valueFrom = var.db_password_secret_arn }] : [],
    var.use_service_url_ssm ? [{ name = "SERVICE_URL", valueFrom = var.service_url_ssm_arn }] : [],
    var.api_extra_secrets
  )
}

# --- タスク定義（API）---
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name_prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${var.ecr_api_repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = local.container_port, protocol = "tcp" }
      ]
      environment    = local.api_env
      secrets        = local.api_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# --- ECS サービス（Rolling デプロイ）---
resource "aws_ecs_service" "api" {
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.internal_security_group_id, aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = local.container_port
    target_group_arn = var.target_group_arn
  }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  enable_execute_command = var.enable_execute_command

  tags = var.tags

  # タスク定義は CI で更新するため Terraform では更新しない
  lifecycle {
    ignore_changes = [task_definition]
  }
}