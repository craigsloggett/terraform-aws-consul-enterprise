# Bastion Host

resource "aws_instance" "bastion" {
  ami                         = var.ec2_ami.id
  instance_type               = var.bastion_instance_type
  key_name                    = var.ec2_key_pair_name
  subnet_id                   = local.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-bastion" })
}

# Consul Nodes

resource "aws_launch_template" "consul" {
  name_prefix   = "${var.project_name}-consul-"
  image_id      = var.ec2_ami.id
  instance_type = var.consul_server_instance_type
  key_name      = var.ec2_key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.consul_server_instance.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.consul.id]
    delete_on_termination       = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64gzip(templatefile("${path.module}/templates/cloud-init.sh.tftpl", {
    consul_version               = var.consul_version
    ebs_device_name              = "/dev/xvdf"
    region                       = data.aws_region.current.region
    consul_license_secret_arn    = aws_secretsmanager_secret.consul_enterprise_license.arn
    consul_gossip_key_secret_arn = aws_secretsmanager_secret.consul_gossip_key.arn

    consul_ca_secret_arn          = aws_secretsmanager_secret.consul_ca.arn
    consul_server_cert_secret_arn = aws_secretsmanager_secret.consul_server_cert.arn
    consul_server_key_secret_arn  = aws_secretsmanager_secret.consul_server_key.arn

    consul_fqdn       = local.consul_fqdn
    consul_datacenter = var.consul_datacenter
    route53_zone_name = var.route53_zone.name

    consul_cluster_tag_key            = local.cluster_tag_key
    consul_cluster_tag_value          = local.cluster_tag_value
    consul_cluster_state_ssm_name     = aws_ssm_parameter.consul_cluster_state.name
    consul_bootstrap_token_secret_arn = aws_secretsmanager_secret.consul_bootstrap_token.arn

    config_server_consul_hcl       = local.config_server_consul_hcl
    config_server_server_hcl       = local.config_server_server_hcl
    config_server_acl_hcl          = local.config_server_acl_hcl
    config_server_auto_encrypt_hcl = local.config_server_auto_encrypt_hcl
    config_server_performance_hcl  = local.config_server_performance_hcl
    config_server_ports_hcl        = local.config_server_ports_hcl
    config_server_tls_hcl          = local.config_server_tls_hcl
    config_server_ui_hcl           = local.config_server_ui_hcl
    config_snapshot_agent_json     = local.config_snapshot_agent_json
    config_consul_service          = local.config_consul_service
    config_snapshot_agent_service  = local.config_snapshot_agent_service
  }))

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Raft Data Storage Volume
  block_device_mappings {
    device_name = "/dev/xvdf"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.consul_ebs_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, {
      Name                    = "${var.project_name}-consul-server"
      (local.cluster_tag_key) = local.cluster_tag_value
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.common_tags, {
      Name = "${var.project_name}-consul"
    })
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = can(regex("(ubuntu|debian)", lower(var.ec2_ami.name)))
      error_message = "The provided AMI must be Ubuntu or Debian-based."
    }
  }
}

resource "aws_autoscaling_group" "consul" {
  name_prefix = "${var.project_name}-consul-"

  min_size         = var.consul_node_count
  max_size         = var.consul_node_count
  desired_capacity = var.consul_node_count

  vpc_zone_identifier = local.vpc.private_subnet_ids

  launch_template {
    id      = aws_launch_template.consul.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 900

  target_group_arns = [aws_lb_target_group.consul.arn]

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = local.instance_refresh_min_healthy_pct
    }
  }

  dynamic "tag" {
    for_each = merge(var.common_tags, {
      (local.cluster_tag_key) = local.cluster_tag_value
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [
    aws_iam_role_policy.consul_server_secrets_manager_read,
    aws_iam_role_policy.consul_server_ssm_read_write,
    aws_iam_role_policy.consul_server_secrets_manager_read_write,
  ]
}
