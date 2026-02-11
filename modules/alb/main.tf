# ALB、ブルー/グリーン用 2 ターゲットグループ、HTTP(S) リスナー。CodeDeploy 連携用。

locals {
  name_prefix = "${var.project_name}-${var.env}"
  listener_default_tg_arn = var.listener_default_target_group == "green" ? aws_lb_target_group.green.arn : aws_lb_target_group.blue.arn
}

# ALB 用 SG: 80 (と optional で 443) を 0.0.0.0/0 から許可
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "ALB - allow HTTP(S) from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  dynamic "ingress" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# ブルー/グリーン用ターゲットグループ（2つ）。Fargate は target_type = ip
resource "aws_lb_target_group" "blue" {
  name        = "${local.name_prefix}-api-blue"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-api-blue"
  })
}

resource "aws_lb_target_group" "green" {
  name        = "${local.name_prefix}-api-green"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-api-green"
  })
}

# リスナー 80: default は blue。CodeDeploy がトラフィックを切り替える。
# 注意: 過去のデプロイ失敗で ECS の primary が green になっている場合は、
# 一時的に default_action を green に変更して apply し、デプロイ成功後に blue に戻す。
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = local.listener_default_tg_arn
  }

  tags = var.tags
}

# green TG を ALB に紐付けるためのルール（ECS CreateService は blue/green 両方の TG が「リスナーに紐付いていること」を要求するため必須）。
# 条件に存在しないホスト (codedeploy-green-placeholder.invalid) を指定しているため通常トラフィックはマッチせず default_action（blue/green のどちらか）へ流れる。
# CodeDeploy は default_action の転送先だけを切り替えてトラフィックシフトするため、このルールは CodeDeploy の挙動と競合しない。
resource "aws_lb_listener_rule" "green_placeholder" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  condition {
    host_header {
      values = ["codedeploy-green-placeholder.invalid"]
    }
  }

  tags = var.tags
}

# 443 は acm_certificate_arn が指定されているときのみ
resource "aws_lb_listener" "https" {
  count = var.acm_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = local.listener_default_tg_arn
  }

  tags = var.tags
}
