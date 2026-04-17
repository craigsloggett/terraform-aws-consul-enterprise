locals {
  consul_fqdn       = "${var.consul_subdomain}.${var.route53_zone.name}"
  consul_node_count = 3
  azs               = slice(data.aws_availability_zones.available.names, 0, 3)
  cluster_tag_key   = "consul-cluster"
  cluster_tag_value = var.project_name
  ebs_device_name   = "/dev/xvdf"

  vault_tls_ca_bundle_ssm_parameter_name = coalesce(
    var.vault_tls_ca_bundle_ssm_parameter_name,
    "/${var.project_name}/vault/tls/ca-bundle",
  )

  created_vpc = var.existing_vpc == null ? module.vpc[0] : null

  vpc = var.existing_vpc != null ? {
    id                 = var.existing_vpc.vpc_id
    cidr               = data.aws_vpc.existing[0].cidr_block
    private_subnet_ids = var.existing_vpc.private_subnet_ids
    public_subnet_ids  = var.existing_vpc.public_subnet_ids
    } : {
    id                 = local.created_vpc.vpc_id
    cidr               = var.vpc_cidr
    private_subnet_ids = local.created_vpc.private_subnets
    public_subnet_ids  = local.created_vpc.public_subnets
  }

  # ---------------------------------------------------------------------------
  # Static configuration files
  # ---------------------------------------------------------------------------

  config_consul_service          = file("${path.module}/files/consul.service")
  config_server_acl_hcl          = file("${path.module}/files/acl.hcl")
  config_server_auto_encrypt_hcl = file("${path.module}/files/auto-encrypt.hcl")
  config_server_performance_hcl  = file("${path.module}/files/performance.hcl")
  config_server_ports_hcl        = file("${path.module}/files/ports.hcl")
  config_server_tls_hcl          = file("${path.module}/files/tls.hcl")
  config_server_ui_hcl           = file("${path.module}/files/ui.hcl")
  config_snapshot_agent_service  = file("${path.module}/files/consul-snapshot-agent.service")

  # ---------------------------------------------------------------------------
  # Rendered configuration files
  # ---------------------------------------------------------------------------

  config_server_consul_hcl = templatefile("${path.module}/templates/consul.hcl.tftpl", {
    datacenter        = var.consul_datacenter
    region            = data.aws_region.current.region
    cluster_tag_key   = local.cluster_tag_key
    cluster_tag_value = local.cluster_tag_value
  })

  config_server_server_hcl = templatefile("${path.module}/templates/server.hcl.tftpl", {
    bootstrap_expect = local.consul_node_count
  })

  config_snapshot_agent_json = templatefile("${path.module}/templates/snapshot-agent.json.tftpl", {
    region                   = data.aws_region.current.region
    consul_snapshot_bucket   = aws_s3_bucket.consul_snapshots.id
    consul_snapshot_interval = var.consul_snapshot_interval
    consul_snapshot_retain   = var.consul_snapshot_retain
  })
}
