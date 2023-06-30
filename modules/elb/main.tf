locals {
  name = "${var.env}-${var.service}"
}

resource "aws_security_group" "default" {
  name        = "${local.name}-alb"
  description = "${var.env} ${var.service} alb security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name}-alb"
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
  security_group_id = aws_security_group.default.id
  description       = "Allow HTTP from anywhere"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_https" {
  security_group_id = aws_security_group.default.id
  description       = "Allow HTTPS from anywhere"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  #tfsec:ignore:aws-ec2-no-public-ingress-sgr
  cidr_blocks = ["0.0.0.0/0"]
}

#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "default" {
  load_balancer_type         = "application"
  name                       = local.name
  security_groups            = [aws_security_group.default.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true # 有効ではないヘッダーフィールドを削除
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
