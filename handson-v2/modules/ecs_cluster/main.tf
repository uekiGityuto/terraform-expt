resource "aws_ecs_cluster" "default" {
  name = "${var.env}-${var.service}"
}
