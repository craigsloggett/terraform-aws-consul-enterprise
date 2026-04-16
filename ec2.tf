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

resource "aws_instance" "consul" {
  count = local.consul_node_count

  ami                    = var.ec2_ami.id
  instance_type          = var.consul_server_instance_type
  key_name               = var.ec2_key_pair_name
  subnet_id              = local.vpc.private_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.consul.id]
  iam_instance_profile   = aws_iam_instance_profile.consul.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    consul_version                 = var.consul_version
    consul_datacenter              = var.consul_datacenter
    consul_fqdn                    = local.consul_fqdn
    ebs_device_name                = local.ebs_device_name
    node_id                        = "consul-${count.index}"
    region                         = data.aws_region.current.region
    consul_license_secret_arn      = aws_secretsmanager_secret.consul_license.arn
    vault_version                  = var.vault_version
    vault_addr                     = local.vault_addr
    vault_ca_cert                  = var.vault_ca_cert
    vault_iam_server_id_header     = local.vault_iam_server_id_header
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
  })

  tags = merge(var.common_tags, {
    Name                    = "${var.project_name}-consul-server-${count.index}"
    (local.cluster_tag_key) = local.cluster_tag_value
  })

  depends_on = [
    aws_iam_role_policy.consul_secrets_manager,
  ]

  lifecycle {
    precondition {
      condition     = can(regex("(ubuntu|debian)", lower(var.ec2_ami.name)))
      error_message = "The provided AMI must be Ubuntu or Debian-based."
    }
  }
}

# EBS Volumes for Raft Storage

resource "aws_ebs_volume" "consul" {
  count = local.consul_node_count

  availability_zone = local.azs[count.index]
  size              = var.consul_ebs_volume_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-data-${count.index}" })
}

resource "aws_volume_attachment" "consul" {
  count = local.consul_node_count

  device_name = local.ebs_device_name
  volume_id   = aws_ebs_volume.consul[count.index].id
  instance_id = aws_instance.consul[count.index].id
}
