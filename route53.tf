resource "aws_route53_record" "consul_enterprise" {
  count = var.route53_zone == null ? 0 : 1

  zone_id = var.route53_zone.zone_id
  name    = var.consul_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.consul_enterprise.dns_name
    zone_id                = aws_lb.consul_enterprise.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    precondition {
      condition     = endswith(var.consul_fqdn, ".${var.route53_zone.name}")
      error_message = "consul_fqdn must be a subdomain of var.route53_zone.name (if provided)."
    }
  }
}
