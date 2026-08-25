resource "aws_lb" "consul_enterprise" {
  name_prefix        = var.nlb.name_prefix
  internal           = var.nlb.internal
  load_balancer_type = "network"
  subnets            = var.nlb.internal ? local.vpc.private_subnet_ids : local.vpc.public_subnet_ids

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.nlb.deletion_protection

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "consul_enterprise" {
  name_prefix = var.nlb.lb_target_group.name_prefix
  port        = 8501
  protocol    = "TCP"
  vpc_id      = local.vpc.id

  # The status endpoints are exempt from ACLs, so this health check needs no
  # token even with default_policy = "deny".
  health_check {
    enabled             = true
    protocol            = "HTTPS"
    port                = "8501"
    path                = "/v1/status/leader"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "consul_enterprise" {
  load_balancer_arn = aws_lb.consul_enterprise.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul_enterprise.arn
  }
}
