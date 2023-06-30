locals {
  name = "${var.env}-${var.service}"
}

resource "aws_ecs_cluster" "default" {
  name = "${var.env}-${var.service}"
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

data "template_file" "container_definitions" {
  template = file("${path.module}/container_definitions.json")
}

resource "aws_ecs_task_definition" "default" {
  family                   = local.name
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = data.template_file.container_definitions.rendered
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
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    #tfsec:ignore:aws-ec2-no-public-egress-sgr
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
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  cidr_blocks = ["0.0.0.0/0"]
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
    container_name   = "nginx"
    container_port   = "80"
  }
}
