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
  instance_type          = var.consul_instance_type
  key_name               = var.ec2_key_pair_name
  subnet_id              = local.vpc.private_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.consul.id]
  iam_instance_profile   = aws_iam_instance_profile.consul.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = templatefile("${path.module}/templates/cloud-init.sh.tftpl", {
    consul_version                = var.consul_package_version
    consul_fqdn                   = trimsuffix(aws_route53_record.consul.fqdn, ".")
    consul_datacenter             = var.consul_datacenter
    node_id                       = "consul-${count.index}"
    region                        = data.aws_region.current.region
    consul_license_secret_arn     = aws_secretsmanager_secret.consul_license.arn
    consul_ca_cert_secret_arn     = aws_secretsmanager_secret.consul_ca_cert.arn
    consul_server_cert_secret_arn = aws_secretsmanager_secret.consul_server_cert.arn
    consul_server_key_secret_arn  = aws_secretsmanager_secret.consul_server_key.arn
    consul_gossip_key_secret_arn  = aws_secretsmanager_secret.consul_gossip_key.arn
    cluster_tag_key               = local.cluster_tag_key
    cluster_tag_value             = local.cluster_tag_value
    ebs_device_name               = local.ebs_device_name
    consul_snapshot_bucket        = aws_s3_bucket.consul_snapshots.id
    consul_snapshot_interval      = var.consul_snapshot_interval
    consul_snapshot_retain        = var.consul_snapshot_retain
  })

  tags = merge(var.common_tags, {
    Name                    = "${var.project_name}-consul-${count.index}"
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

  device_name                    = local.ebs_device_name
  volume_id                      = aws_ebs_volume.consul[count.index].id
  instance_id                    = aws_instance.consul[count.index].id
  stop_instance_before_detaching = true

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 modify-instance-attribute \
        --instance-id ${self.instance_id} \
        --block-device-mappings '[{"DeviceName":"${self.device_name}","Ebs":{"DeleteOnTermination":true}}]' \
        --region ${data.aws_region.current.region}
    EOT
  }
}
