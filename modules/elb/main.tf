locals {
  name = "${var.env}-${var.service}"
}

resource "aws_security_group" "default" {
  name        = "${local.name}-alb"
  description = "${var.env} ${var.service} alb"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.default.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.default.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb" "default" {
  load_balancer_type = "application"
  name               = local.name
  # TODO: "${}"いらない気がする
  security_groups = ["${aws_security_group.default.id}"]
  subnets         = var.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  port              = "80"
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.default.arn

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.acm_id
  load_balancer_arn = aws_lb.default.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "ok"
    }
  }
}

data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "default" {
  type    = "A"
  name    = var.domain
  zone_id = data.aws_route53_zone.default.id

  alias {
    name                   = aws_lb.default.dns_name
    zone_id                = aws_lb.default.zone_id
    evaluate_target_health = true
  }
}
