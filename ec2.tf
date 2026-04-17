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

  user_data_base64 = base64gzip(templatefile("${path.module}/templates/user-data.sh.tftpl", {
    consul_version               = var.consul_version
    vault_version                = var.vault_version
    ebs_device_name              = local.ebs_device_name
    node_id                      = "consul-${count.index}"
    region                       = data.aws_region.current.region
    consul_license_secret_arn    = aws_secretsmanager_secret.consul_license.arn
    consul_gossip_key_secret_arn = aws_secretsmanager_secret.consul_gossip_key.arn

    vault_addr               = local.vault_url
    vault_ca_bundle_ssm_name = local.vault_tls_ca_bundle_ssm_parameter_name
    vault_pki_mount          = var.vault_pki_mount
    vault_pki_role           = var.vault_pki_role
    vault_aws_auth_role      = var.vault_aws_auth_role
    consul_server_cert_ttl   = var.consul_server_cert_ttl

    consul_fqdn       = local.consul_fqdn
    consul_datacenter = var.consul_datacenter
    route53_zone_name = var.route53_zone.name

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

  tags = merge(var.common_tags, {
    Name                    = "${var.project_name}-consul-server-${count.index}"
    (local.cluster_tag_key) = local.cluster_tag_value
  })

  depends_on = [
    aws_iam_role_policy.consul_secrets_manager,
    aws_iam_role_policy.consul_vault_ca_bundle,
    aws_iam_role_policy.vault_resolve_consul_role,
    vault_aws_auth_backend_role.consul_server,
    vault_pki_secret_backend_role.consul_server,
    vault_pki_secret_backend_intermediate_set_signed.pki_consul,
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
