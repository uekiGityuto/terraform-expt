resource "aws_ecr_repository" "default" {
  name                 = "${var.env}-${var.service}"
  image_tag_mutability = "MUTABLE"
}
