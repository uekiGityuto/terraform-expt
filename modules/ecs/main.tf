locals {
  name           = "${var.env}-${var.service}"
  log_gruop      = "/${var.env}/${var.service}/app"
  container_name = "app"
}

#tfsec:ignore:aws-ecr-repository-customer-key
resource "aws_ecr_repository" "default" {
  name                 = "${var.env}-${var.service}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "default" {
  name = "${var.env}-${var.service}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ssm_policy" {
  statement {
    actions = ["ssm:GetParameters"]
    # ワイルドカード(*)を使った方が保守性が高い可能性あり
    # e.g. "arn:aws:ssm:ap-northeast-1:${var.data.aws_caller_identity.current.account_id}:parameter/${var.env}/${var.service}/app/*"
    resources = [var.pgpassword_arn, var.secret_key_arn]
  }
}

resource "aws_iam_policy" "ssm_policy" {
  name   = "${local.name}-ssm-policy"
  policy = data.aws_iam_policy_document.ssm_policy.json
}

resource "aws_iam_role" "task_execution_role" {
  name               = "${local.name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "default" {
  name              = local.log_gruop
  retention_in_days = 90
}

resource "aws_ecs_task_definition" "default" {
  family                   = local.name
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  container_definitions = jsonencode([
    {
      name = local.container_name
      # TODO: tag指定する必要あり
      image = aws_ecr_repository.default.repository_url
      portMappings = [{
        hostPort : 80,
        containerPort : 80
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region : "ap-northeast-1"
          awslogs-group : local.log_gruop
          awslogs-stream-prefix : "ecs"
        }
      }
      environment = [
        {
          name : "WORKERS_PER_CORE",
          value : var.workers_per_core
        },
        {
          name : "WEB_CONCURRENCY",
          value : var.web_concurrency
        },
        {
          name : "PGHOST",
          value : var.pghost
        },
        {
          name : "PGPORT",
          value : var.pgport
        },
        {
          name : "PGDATABASE",
          value : var.pgdatabase
        },
        {
          name : "PGUSER",
          value : var.pguser
        },
        {
          name : "ALGORITHM",
          value : var.algorithm
        },
        {
          name : "ACCESS_TOKEN_EXPIRE_MINUTES",
          value : var.access_token_expire_minutes
        },
      ],
      secrets = [
        {
          name : "PGPASSWORD",
          valueFrom : var.pgpassword_arn
        },
        {
          name : "SECRET_KEY",
          valueFrom : var.secret_key_arn
        },
      ]
    }
  ])
  # 以下のplatformに合わせてDocker Imageを作成する
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

# CodePipeline等でアプリケーション側のデプロイをすると、Terraform管理のタスク定義のリビジョンとずれるので最新のリビジョンを取得する
data "aws_ecs_task_definition" "default" {
  task_definition = aws_ecs_task_definition.default.family
}

resource "aws_lb_target_group" "default" {
  name        = local.name
  vpc_id      = var.vpc_id
  port        = 80
  target_type = "ip"
  protocol    = "HTTP"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = 80
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = 200
  }
}

resource "aws_lb_listener_rule" "default" {
  listener_arn = var.https_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.id
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

resource "aws_security_group" "default" {
  name        = "${local.name}-ecs"
  description = "${var.env} ${var.service} ecs security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name}-ecs"
  }
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.default.id
  description       = "Allow all to anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_http" {
  security_group_id        = aws_security_group.default.id
  description              = "Allow HTTP from ELB"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.elb_security_group_id
}

resource "aws_ecs_service" "default" {
  depends_on                         = [aws_lb_listener_rule.default]
  name                               = local.name
  platform_version                   = "LATEST"
  cluster                            = aws_ecs_cluster.default.name
  task_definition                    = data.aws_ecs_task_definition.default.arn
  launch_type                        = "FARGATE"
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.default.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.default.arn
    container_name   = local.container_name
    container_port   = "80"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
