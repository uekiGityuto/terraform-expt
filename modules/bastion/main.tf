locals {
  name = "${var.env}-${var.service}"
}

resource "aws_security_group" "default" {
  name        = "${local.name}-bastion"
  description = "${var.env} ${var.service} code-build security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name}-bastion"
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

resource "aws_instance" "default" {
  ami                         = "ami-0689ba4565ed58788"
  instance_type               = "t4g.micro"
  subnet_id                   = var.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.default.id]
  iam_instance_profile        = aws_iam_instance_profile.default.name
  associate_public_ip_address = true

  user_data = file("${path.module}/user_data.sh")

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${local.name}-bastion"
  }
}

data "aws_iam_policy_document" "default" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ssm" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "default" {
  name               = "${local.name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.default.json
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = data.aws_iam_policy.ssm.arn
}

resource "aws_iam_instance_profile" "default" {
  name = "${local.name}-bastion-profile"
  role = aws_iam_role.default.name
}
