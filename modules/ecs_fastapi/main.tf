locals {
  name           = "${var.env}-${var.service}"
  log_gruop      = "/${var.env}/${var.service}/backend"
  container_name = "fastapi"
}

resource "aws_ecr_repository" "default" {
  name                 = "${var.env}-${var.service}-backend"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecs_cluster" "default" {
  name = "${var.env}-${var.service}-backend"
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

resource "aws_cloudwatch_log_group" "default" {
  name              = local.log_gruop
  retention_in_days = 90
}

resource "aws_ecs_task_definition" "default" {
  family                   = local.name
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  container_definitions = jsonencode([
    {
      name  = local.container_name
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
          value : "3"
        },
        {
          name : "WEB_CONCURRENCY",
          value : "2"
        }
      ]
    }
  ])
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
  name        = local.name
  description = local.name
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.name
  }
}

resource "aws_security_group_rule" "default" {
  security_group_id = aws_security_group.default.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_ecs_service" "default" {
  depends_on      = [aws_lb_listener_rule.default]
  name            = local.name
  launch_type     = "FARGATE"
  desired_count   = 1
  cluster         = aws_ecs_cluster.default.name
  task_definition = aws_ecs_task_definition.default.arn

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.default.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.default.arn
    container_name   = local.container_name
    container_port   = "80"
  }
}