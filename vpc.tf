module "vpc" {
  count = var.existing_vpc == null ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = var.project_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.common_tags
}

# VPC Endpoints

resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.existing_vpc == null ? 1 : 0

  vpc_id              = module.vpc[0].vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc[0].private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-secretsmanager" })
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.existing_vpc == null ? 1 : 0

  vpc_id              = module.vpc[0].vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc[0].private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-ec2" })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.existing_vpc == null ? 1 : 0

  vpc_id            = module.vpc[0].vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc[0].private_route_table_ids

  tags = merge(var.common_tags, { Name = "${var.project_name}-s3" })
}

# Security Groups

resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-"
  description = "Security group for the bastion host"
  vpc_id      = local.vpc.id

  tags = merge(var.common_tags, { Name = "${var.project_name}-bastion" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.bastion_allowed_cidrs)

  security_group_id = aws_security_group.bastion.id
  description       = "SSH from allowed CIDR"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "consul" {
  name_prefix = "${var.project_name}-consul-"
  description = "Security group for Consul nodes"
  vpc_id      = local.vpc.id

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "consul_api" {
  security_group_id = aws_security_group.consul.id
  description       = "Consul HTTPS API from VPC"
  from_port         = 8501
  to_port           = 8501
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_vpc_security_group_ingress_rule" "consul_api_external" {
  for_each = toset(var.consul_api_allowed_cidrs)

  security_group_id = aws_security_group.consul.id
  description       = "Consul HTTPS API from external CIDR"
  from_port         = 8501
  to_port           = 8501
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "consul_rpc" {
  security_group_id            = aws_security_group.consul.id
  description                  = "Consul server RPC"
  from_port                    = 8300
  to_port                      = 8300
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_lan_serf_tcp" {
  security_group_id            = aws_security_group.consul.id
  description                  = "Consul LAN Serf TCP"
  from_port                    = 8301
  to_port                      = 8301
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_lan_serf_udp" {
  security_group_id            = aws_security_group.consul.id
  description                  = "Consul LAN Serf UDP"
  from_port                    = 8301
  to_port                      = 8301
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.consul.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_wan_serf_tcp" {
  security_group_id            = aws_security_group.consul.id
  description                  = "Consul WAN Serf TCP"
  from_port                    = 8302
  to_port                      = 8302
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_wan_serf_udp" {
  security_group_id            = aws_security_group.consul.id
  description                  = "Consul WAN Serf UDP"
  from_port                    = 8302
  to_port                      = 8302
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.consul.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_ssh" {
  security_group_id            = aws_security_group.consul.id
  description                  = "SSH from bastion"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "consul_all" {
  security_group_id = aws_security_group.consul.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.existing_vpc == null ? 1 : 0

  name_prefix = "${var.project_name}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc[0].vpc_id

  tags = merge(var.common_tags, { Name = "${var.project_name}-vpc-endpoints" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = var.existing_vpc == null ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "HTTPS from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}
