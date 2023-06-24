data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

resource "aws_acm_certificate" "default" {
  domain_name       = var.domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "default" {
  depends_on = [aws_acm_certificate.default]

  for_each = {
    for dvo in aws_acm_certificate.default.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.default.id
  ttl     = 60
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn         = aws_acm_certificate.default.arn
  validation_record_fqdns = [for record in aws_route53_record.default : record.fqdn]
}
