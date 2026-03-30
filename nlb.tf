resource "aws_lb" "consul" {
  name_prefix        = "consl-"
  internal           = var.nlb_internal
  load_balancer_type = "network"
  subnets            = var.nlb_internal ? local.vpc.private_subnet_ids : local.vpc.public_subnet_ids

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "consul" {
  name_prefix = "consl-"
  port        = 8501
  protocol    = "TLS"
  vpc_id      = local.vpc.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "8501"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "consul" {
  load_balancer_arn = aws_lb.consul.arn
  port              = 8501
  protocol          = "TLS"
  certificate_arn   = aws_acm_certificate_validation.consul.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul.arn
  }
}

resource "aws_lb_target_group_attachment" "consul" {
  count = local.consul_node_count

  target_group_arn = aws_lb_target_group.consul.arn
  target_id        = aws_instance.consul[count.index].id
  port             = 8501
}
