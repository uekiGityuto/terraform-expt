locals {
  name           = "${var.env}-${var.service}"
  log_gruop      = "/${var.env}/${var.service}/app"
  container_name = "app"
}

#tfsec:ignore:aws-ecr-repository-customer-key
resource "aws_ecr_repository" "default" {
  name = "${var.env}-${var.service}"
  # FIXME: 可能であればIMMUTABLEにする
  #tfsec:ignore:aws-ecr-enforce-immutable-repository
  image_tag_mutability = "MUTABLE"

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

resource "aws_iam_role" "task_execution_role" {
  name               = "${local.name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "task_execution_role_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
      # TODO: tagを指定しなくて良いのかは要検討。
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
      # TODO: 環境変数の渡し方は要検討（最低でも変数化する）
      environment = [
        {
          name : "WORKERS_PER_CORE",
          value : "3"
        },
        {
          name : "WEB_CONCURRENCY",
          value : "2"
        }
      ]
    }
  ])
  # 以下のplatformに合わせてDocker Imageを作成する
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_lb_target_group" "default" {
  name        = local.name
  vpc_id      = var.vpc_id
  port        = 80
  target_type = "ip"
  protocol    = "HTTP"

  health_check {
    port = 80
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
  task_definition                    = aws_ecs_task_definition.default.arn
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
