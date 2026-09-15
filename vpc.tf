module "vpc" {
  count = var.vpc.existing == null ? 1 : 0

  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.vpc.name
  cidr = var.vpc.cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.vpc.private_subnets
  public_subnets  = var.vpc.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = 90

  vpc_flow_log_iam_role_name            = "ConsulEnterpriseVPCFlowLogsRole"
  vpc_flow_log_iam_role_use_name_prefix = false
}

# VPC Endpoints

resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.vpc.existing == null ? 1 : 0

  vpc_id              = module.vpc[0].vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc[0].private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = var.vpc.endpoints.secretsmanager_name
  }
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.vpc.existing == null ? 1 : 0

  vpc_id              = module.vpc[0].vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc[0].private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = var.vpc.endpoints.ec2_name
  }
}

resource "aws_vpc_endpoint" "s3" {
  count = var.vpc.existing == null ? 1 : 0

  vpc_id            = module.vpc[0].vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc[0].private_route_table_ids

  tags = {
    Name = var.vpc.endpoints.s3_name
  }
}

# Security Groups

resource "aws_security_group" "bastion" {
  name_prefix = var.bastion.security_group.name_prefix
  description = "Bastion host security group"
  vpc_id      = local.vpc.id

  tags = {
    Name = var.bastion.security_group.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.bastion.allowed_cidrs)

  security_group_id = aws_security_group.bastion.id
  description       = "SSH from allowed CIDR"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "bastion_ssh" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "SSH traffic to the Consul servers"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_egress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion.id
  description       = "HTTPS traffic for OS packages"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_http" {
  security_group_id = aws_security_group.bastion.id
  description       = "HTTP traffic for OS package mirrors"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_ntp" {
  security_group_id = aws_security_group.bastion.id
  description       = "NTP traffic to distribution pool servers"
  from_port         = 123
  to_port           = 123
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_dns_tcp" {
  security_group_id = aws_security_group.bastion.id
  description       = "DNS traffic to VPC resolvers"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_dns_udp" {
  security_group_id = aws_security_group.bastion.id
  description       = "DNS traffic to VPC resolvers"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_security_group" "consul_enterprise_servers" {
  name_prefix = var.compute.security_group.name_prefix
  description = "Consul Enterprise servers security group"
  vpc_id      = local.vpc.id

  tags = {
    Name = var.compute.security_group.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_https_api" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "Consul Enterprise HTTPS API traffic from VPC"
  from_port         = 8501
  to_port           = 8501
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_https_api_external" {
  for_each = toset(var.nlb.api_allowed_cidrs)

  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "Consul Enterprise HTTPS API traffic from external CIDR"
  from_port         = 8501
  to_port           = 8501
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_server_rpc" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise server RPC traffic"
  from_port                    = 8300
  to_port                      = 8300
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_serf_lan_tcp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf LAN gossip traffic"
  from_port                    = 8301
  to_port                      = 8301
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_serf_lan_udp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf LAN gossip traffic"
  from_port                    = 8301
  to_port                      = 8301
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_serf_wan_tcp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf WAN gossip traffic"
  from_port                    = 8302
  to_port                      = 8302
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_serf_wan_udp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf WAN gossip traffic"
  from_port                    = 8302
  to_port                      = 8302
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_dns_tcp" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "Consul Enterprise DNS traffic from VPC"
  from_port         = 8600
  to_port           = 8600
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_vpc_security_group_ingress_rule" "consul_enterprise_dns_udp" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "Consul Enterprise DNS traffic from VPC"
  from_port         = 8600
  to_port           = 8600
  ip_protocol       = "udp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_vpc_security_group_ingress_rule" "consul_ssh" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "SSH traffic from the bastion host"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "consul_https" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "HTTPS traffic for AWS APIs and HashiCorp releases"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "consul_http" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "HTTP traffic for OS package mirrors"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# The HTTPS egress rule above already covers a Vault cluster listening on 443;
# creating this rule in that case would conflict with it.
resource "aws_vpc_security_group_egress_rule" "consul_external_vault" {
  count = var.external_vault.port == 443 ? 0 : 1

  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "Vault API traffic to the external Vault cluster"
  from_port         = var.external_vault.port
  to_port           = var.external_vault.port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "consul_server_rpc" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise server RPC traffic"
  from_port                    = 8300
  to_port                      = 8300
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_egress_rule" "consul_serf_lan_tcp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf LAN gossip traffic"
  from_port                    = 8301
  to_port                      = 8301
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_egress_rule" "consul_serf_lan_udp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf LAN gossip traffic"
  from_port                    = 8301
  to_port                      = 8301
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_egress_rule" "consul_serf_wan_tcp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf WAN gossip traffic"
  from_port                    = 8302
  to_port                      = 8302
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_egress_rule" "consul_serf_wan_udp" {
  security_group_id            = aws_security_group.consul_enterprise_servers.id
  description                  = "Consul Enterprise Serf WAN gossip traffic"
  from_port                    = 8302
  to_port                      = 8302
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.consul_enterprise_servers.id
}

resource "aws_vpc_security_group_egress_rule" "consul_ntp" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "NTP traffic to distribution pool servers"
  from_port         = 123
  to_port           = 123
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "consul_dns_tcp" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "DNS traffic to VPC resolvers"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_vpc_security_group_egress_rule" "consul_dns_udp" {
  security_group_id = aws_security_group.consul_enterprise_servers.id
  description       = "DNS traffic to VPC resolvers"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = local.vpc.cidr
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.vpc.existing == null ? 1 : 0

  name_prefix = var.vpc.endpoints.security_group.name_prefix
  description = "Consul Enterprise VPC endpoints security group"
  vpc_id      = module.vpc[0].vpc_id

  tags = {
    Name = var.vpc.endpoints.security_group.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = var.vpc.existing == null ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "HTTPS traffic from VPC"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc.cidr
}
