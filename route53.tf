resource "aws_route53_record" "consul" {
  zone_id = var.route53_zone.zone_id
  name    = local.consul_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.consul.dns_name
    zone_id                = aws_lb.consul.zone_id
    evaluate_target_health = true
  }
}
