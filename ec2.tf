# Bastion Host

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.selected.id
  instance_type               = var.bastion.instance_type
  key_name                    = var.key_pair.key_name
  subnet_id                   = local.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = var.bastion.name
  }

  volume_tags = {
    Name = var.bastion.volume_name
  }
}

# Consul Nodes

resource "aws_launch_template" "consul_enterprise" {
  name_prefix            = var.compute.launch_template.name_prefix
  image_id               = data.aws_ami.selected.id
  instance_type          = var.compute.instance_type
  key_name               = var.key_pair.key_name
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.consul_enterprise.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.consul_enterprise_servers.id]
    delete_on_termination       = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64gzip(templatefile("${path.module}/templates/cloud-init.yml.tftpl", {
    bootstrap_env_file = templatefile("${path.module}/templates/bootstrap.env.tftpl", {
      # Environment
      consul_datacenter = var.consul.datacenter
      consul_fqdn       = var.consul_fqdn
      consul_version    = var.consul.version

      vault_agent_version = var.vault_agent.version

      # Auto-join Discovery
      auto_join_tag_key   = var.compute.auto_join.tag_key
      auto_join_tag_value = var.compute.auto_join.tag_value

      # Bootstrap Coordination
      bootstrap_consul_cluster_state_ssm_parameter_name = aws_ssm_parameter.bootstrap_consul_cluster_state.name
      bootstrap_instance_id_ssm_parameter_name          = aws_ssm_parameter.bootstrap_instance_id.name

      # Bootstrap Secrets
      license_secret_arn                  = aws_secretsmanager_secret.license.arn
      acl_management_token_secret_arn     = aws_secretsmanager_secret.acl_management_token.arn
      acl_agent_token_secret_arn          = aws_secretsmanager_secret.acl_agent_token.arn
      acl_snapshot_agent_token_secret_arn = aws_secretsmanager_secret.acl_snapshot_agent_token.arn

      # EBS Storage
      consul_audit_log_ebs_attachment_name = "/dev/xvdg"
      consul_raft_data_ebs_attachment_name = "/dev/xvdf"
    })

    # Bootstrap Scripts
    script_common_functions                  = file("${path.module}/files/bootstrap/common-functions.sh")
    script_determine_consul_node_role        = file("${path.module}/files/bootstrap/determine-consul-node-role.sh")
    script_install_consul                    = file("${path.module}/files/bootstrap/install-consul.sh")
    script_install_vault                     = file("${path.module}/files/bootstrap/install-vault.sh")
    script_install_consul_enterprise_license = file("${path.module}/files/bootstrap/install-consul-enterprise-license.sh")
    script_prepare_consul_storage            = file("${path.module}/files/bootstrap/prepare-consul-storage.sh")
    script_start_vault_agent                 = file("${path.module}/files/bootstrap/start-vault-agent.sh")
    script_start_consul                      = file("${path.module}/files/bootstrap/start-consul.sh")
    script_initialize_consul_acl             = file("${path.module}/files/bootstrap/initialize-consul-acl.sh")
    script_await_consul_cluster              = file("${path.module}/files/bootstrap/await-consul-cluster.sh")
    script_configure_consul_acl_tokens       = file("${path.module}/files/bootstrap/configure-consul-acl-tokens.sh")
    script_configure_snapshots               = file("${path.module}/files/bootstrap/configure-snapshots.sh")

    # External Vault Trust Anchor
    external_vault_ca_chain_pem = var.external_vault.ca_chain_pem

    # Consul Server Configuration
    config_consul_cli = templatefile("${path.module}/templates/consul/cli-config.sh.tftpl", {
      consul_fqdn = var.consul_fqdn
    })

    config_consul_hcl = templatefile("${path.module}/templates/consul/consul.hcl.tftpl", {
      datacenter                = var.consul.datacenter
      ui                        = var.consul.ui
      log_level                 = var.consul.log_level
      log_json                  = var.consul.log_json
      bootstrap_expect          = var.compute.node_count
      audit_rotate_duration     = var.consul.audit.rotate_duration
      audit_rotate_max_files    = var.consul.audit.rotate_max_files
      prometheus_retention_time = var.consul.telemetry.prometheus_retention_time
      disable_hostname          = var.consul.telemetry.disable_hostname
      aws_region                = data.aws_region.current.region
      auto_join_tag_key         = var.compute.auto_join.tag_key
      auto_join_tag_value       = var.compute.auto_join.tag_value
    })

    config_consul_snapshot_json = templatefile("${path.module}/templates/consul/snapshot.json.tftpl", {
      aws_s3_bucket = aws_s3_bucket.snapshots.id
      aws_s3_region = data.aws_region.current.region
      s3_key_prefix = var.consul_snapshot.s3_key_prefix
      interval      = var.consul_snapshot.interval
      retain        = var.consul_snapshot.retain
    })

    config_consul_agent_policy          = file("${path.module}/files/policies/consul-agent.hcl")
    config_consul_snapshot_agent_policy = file("${path.module}/files/policies/consul-snapshot-agent.hcl")

    config_consul_service                = file("${path.module}/files/consul/consul.service")
    config_consul_snapshot_agent_service = file("${path.module}/files/consul/consul-snapshot-agent.service")

    # Vault Agent Configuration
    config_vault_agent_hcl = templatefile("${path.module}/templates/agent/agent.hcl.tftpl", {
      vault_address         = var.external_vault.address
      vault_tls_server_name = var.external_vault.tls_server_name
      auth_aws_mount_path   = var.external_vault.auth_aws.mount_path
      auth_aws_role_name    = var.external_vault.auth_aws.role_name
      auth_aws_header_value = var.external_vault.auth_aws.header_value
    })

    config_vault_agent_consul_server_tls_ctmpl = templatefile("${path.module}/templates/agent/consul-server-tls.ctmpl.tftpl", {
      consul_fqdn         = var.consul_fqdn
      consul_datacenter   = var.consul.datacenter
      pki_mount_path      = var.external_vault.pki.mount_path
      pki_role_name       = var.external_vault.pki.role_name
      pki_server_cert_ttl = var.external_vault.pki.server_cert_ttl
    })

    config_vault_agent_consul_gossip_ctmpl = templatefile("${path.module}/templates/agent/consul-gossip.ctmpl.tftpl", {
      kv_mount_path      = var.external_vault.kv.mount_path
      gossip_secret_path = var.external_vault.kv.gossip_secret_path
      gossip_key_field   = var.external_vault.kv.gossip_key_field
    })

    config_vault_agent_service                  = file("${path.module}/files/agent/vault-agent.service")
    config_vault_agent_reload_rules             = file("${path.module}/files/agent/vault-agent-reload.rules")
    config_vault_agent_reload_consul_server_tls = file("${path.module}/files/agent/consul-server-tls-reload.sh")
  }))

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.compute.root_disk.volume_size
      iops                  = var.compute.root_disk.iops
      throughput            = var.compute.root_disk.throughput
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Raft Data Storage Volume
  block_device_mappings {
    device_name = "/dev/xvdf"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.compute.raft_data_disk.volume_size
      iops                  = var.compute.raft_data_disk.iops
      throughput            = var.compute.raft_data_disk.throughput
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Audit Log Storage Volume
  block_device_mappings {
    device_name = "/dev/xvdg"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.compute.audit_disk.volume_size
      iops                  = var.compute.audit_disk.iops
      throughput            = var.compute.audit_disk.throughput
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = var.compute.launch_template.volume_name
    }
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = can(regex("(ubuntu|debian)", lower(var.ami.name)))
      error_message = "The provided AMI must be Ubuntu or Debian-based."
    }

    precondition {
      condition = (
        local.root_disk_at_floor ||
        var.compute.root_disk.iops <= data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops
      )
      error_message = format(
        "compute.root_disk.iops (%d) exceeds the %s baseline EBS IOPS (%d). The instance cannot sustain this provisioned IOPS, so you would be billed for unusable capacity. Set iops to %d to match the instance, or choose a larger instance type.",
        var.compute.root_disk.iops,
        var.compute.instance_type,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops,
      )
    }

    precondition {
      condition = (
        local.root_disk_at_floor ||
        var.compute.root_disk.throughput <= data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput
      )
      error_message = format(
        "compute.root_disk.throughput (%d MiB/s) exceeds the %s baseline EBS throughput (%.1f MiB/s). The instance cannot sustain this provisioned throughput, so you would be billed for unusable capacity. Set throughput to %d to match the instance, or choose a larger instance type.",
        var.compute.root_disk.throughput,
        var.compute.instance_type,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput,
        floor(data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput),
      )
    }

    precondition {
      condition = (
        local.raft_data_disk_at_floor ||
        var.compute.raft_data_disk.iops <= data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops
      )
      error_message = format(
        "compute.raft_data_disk.iops (%d) exceeds the %s baseline EBS IOPS (%d). The instance cannot sustain this provisioned IOPS, so you would be billed for unusable capacity. Set iops to %d to match the instance, or choose a larger instance type.",
        var.compute.raft_data_disk.iops,
        var.compute.instance_type,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops,
      )
    }

    precondition {
      condition = (
        local.raft_data_disk_at_floor ||
        var.compute.raft_data_disk.throughput <= data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput
      )
      error_message = format(
        "compute.raft_data_disk.throughput (%d MiB/s) exceeds the %s baseline EBS throughput (%.1f MiB/s). The instance cannot sustain this provisioned throughput, so you would be billed for unusable capacity. Set throughput to %d to match the instance, or choose a larger instance type.",
        var.compute.raft_data_disk.throughput,
        var.compute.instance_type,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput,
        floor(data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput),
      )
    }

    precondition {
      condition = (
        local.audit_disk_at_floor ||
        var.compute.audit_disk.iops <= data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops
      )
      error_message = format(
        "compute.audit_disk.iops (%d) exceeds the %s baseline EBS IOPS (%d). The instance cannot sustain this provisioned IOPS, so you would be billed for unusable capacity. Set iops to %d to match the instance, or choose a larger instance type.",
        var.compute.audit_disk.iops,
        var.compute.instance_type,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_iops,
      )
    }

    precondition {
      condition = (
        local.audit_disk_at_floor ||
        var.compute.audit_disk.throughput <= data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput
      )
      error_message = format(
        "compute.audit_disk.throughput (%d MiB/s) exceeds the %s baseline EBS throughput (%.1f MiB/s). The instance cannot sustain this provisioned throughput, so you would be billed for unusable capacity. Set throughput to %d to match the instance, or choose a larger instance type.",
        var.compute.audit_disk.throughput,
        var.compute.instance_type,
        data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput,
        floor(data.aws_ec2_instance_type.compute.ebs_performance_baseline_throughput),
      )
    }
  }
}

resource "aws_autoscaling_group" "consul_enterprise" {
  name_prefix = var.compute.autoscaling_group.name_prefix

  min_size         = var.compute.node_count
  max_size         = var.compute.node_count
  desired_capacity = var.compute.node_count

  vpc_zone_identifier = local.vpc.private_subnet_ids

  launch_template {
    id      = aws_launch_template.consul_enterprise.id
    version = var.compute.autoscaling_group.launch_template_version
  }

  health_check_type         = "ELB"
  health_check_grace_period = 900

  target_group_arns = [aws_lb_target_group.consul_enterprise.arn]

  instance_refresh {
    strategy = "Rolling"

    preferences {
      skip_matching    = true
      instance_warmup  = 900
      checkpoint_delay = 300

      # Replace 1 node at a time.
      min_healthy_percentage = floor(
        (var.compute.node_count - 1) * 100 / var.compute.node_count
      )
    }
  }

  tag {
    key                 = var.compute.auto_join.tag_key
    value               = var.compute.auto_join.tag_value
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = var.compute.autoscaling_group.instance_name
    propagate_at_launch = true
  }
}
