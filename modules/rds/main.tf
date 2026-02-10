resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.env}-rds"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-rds-subnet"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.env}-rds-"
  description = "RDS PostgreSQL - allow from ECS only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "PostgreSQL from ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.env}-postgres"

  engine               = "postgres"
  engine_version       = "17"
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage_gb
  storage_encrypted    = true
  multi_az             = var.multi_az
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible  = false

  db_name  = "main"
  username = "postgres"
  password = var.db_password

  backup_retention_period = 7
  skip_final_snapshot     = var.env != "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.env}-rds"
  })
}
