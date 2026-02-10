# AWS Batch: compute environment (Fargate)、job queue、job definition。
# job queue 名 = {env}_default、job definition 名 = {env}_fastapi_default_job（aws_caller.py と一致）

data "aws_iam_policy_document" "batch_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "batch_service" {
  name               = "${var.project_name}-${var.env}-batch-service"
  assume_role_policy = data.aws_iam_policy_document.batch_assume.json
}

resource "aws_iam_role_policy_attachment" "batch_service" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_security_group" "batch" {
  name_prefix = "${var.project_name}-${var.env}-batch-"
  description = "AWS Batch Fargate"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-batch-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_batch_compute_environment" "main" {
  compute_environment_name = "${var.project_name}-${var.env}-batch"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service.arn

  compute_resources {
    type                = "FARGATE"
    max_vcpus           = 256
    security_group_ids  = [aws_security_group.batch.id]
    subnets             = var.private_subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}

resource "aws_batch_job_queue" "default" {
  name     = "${var.env}_default"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.main.arn
  }
}

# Job definition: アプリ用コンテナは ECR イメージに差し替える。ここではプレースホルダー。
resource "aws_batch_job_definition" "fastapi_default" {
  name                  = "${var.env}_fastapi_default_job"
  type                  = "container"
  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image   = var.batch_job_image
    command = ["echo", "hello"]
    executionRoleArn = aws_iam_role.batch_task_execution.arn
    resourceRequirements = [
      { type = "VCPU", value = "0.25" },
      { type = "MEMORY", value = "512" }
    ]
    networkConfiguration = {
      assignPublicIp = "DISABLED"
    }
  })
}

# Fargate タスク実行用ロール（ECR 等プル用）
resource "aws_iam_role" "batch_task_execution" {
  name = "${var.project_name}-${var.env}-batch-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_task_execution" {
  role       = aws_iam_role.batch_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
