# Required

variable "consul_enterprise_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}

variable "consul_fqdn" {
  type        = string
  description = <<-EOT
    Fully qualified domain name in presentation form for the Consul Enterprise
    cluster. Used as the TLS certificate common name and the public API
    endpoint behind the NLB.
  EOT

  validation {
    condition     = length(var.consul_fqdn) > 0 && length(var.consul_fqdn) <= 253
    error_message = "consul_fqdn must be 1-253 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.consul_fqdn))
    error_message = "consul_fqdn may only contain lowercase letters, digits, hyphens, and dots."
  }

  validation {
    condition     = !startswith(var.consul_fqdn, ".") && !endswith(var.consul_fqdn, ".")
    error_message = "consul_fqdn must not start or end with a dot (in the presentation form)."
  }

  validation {
    condition     = !strcontains(var.consul_fqdn, "..")
    error_message = "consul_fqdn must not contain empty labels (consecutive dots)."
  }

  validation {
    condition     = strcontains(var.consul_fqdn, ".")
    error_message = "consul_fqdn must contain at least one dot."
  }

  validation {
    condition     = alltrue([for label in split(".", var.consul_fqdn) : length(label) >= 1 && length(label) <= 63])
    error_message = "Each label must be 1-63 characters."
  }

  validation {
    condition     = alltrue([for label in split(".", var.consul_fqdn) : !startswith(label, "-") && !endswith(label, "-")])
    error_message = "Labels must not start or end with a hyphen."
  }
}

variable "external_vault" {
  type = object({
    address         = string
    port            = optional(number, 8200)
    tls_server_name = optional(string, "")
    ca_chain_pem    = string

    auth_aws = optional(object({
      mount_path   = optional(string, "aws")
      role_name    = optional(string, "consul-server")
      header_value = optional(string, "")
    }), {})

    pki = optional(object({
      mount_path      = optional(string, "pki_consul")
      role_name       = optional(string, "consul-server")
      server_cert_ttl = optional(string, "24h")
    }), {})

    kv = optional(object({
      mount_path         = optional(string, "kv")
      gossip_secret_path = optional(string, "consul/gossip")
      gossip_key_field   = optional(string, "key")
    }), {})
  })

  description = <<-EOT
    Pre-existing Vault cluster that manages PKI and the gossip encryption key
    for the Consul servers. The module makes no configuration changes to this
    cluster; a Vault Agent on every Consul server authenticates with the AWS
    auth method at `auth_aws.mount_path` using `auth_aws.role_name` (which must
    be bound to this module's `iam_role_arn` output), issues the server TLS
    certificate from the PKI role at `pki.mount_path`/issue/`pki.role_name`,
    and reads the gossip encryption key from the KV v2 secret at
    `kv.mount_path`/`kv.gossip_secret_path` under `kv.gossip_key_field`.
    `port` only feeds the security group egress rule; `address` carries the
    port the agent connects to.
  EOT

  validation {
    condition     = startswith(var.external_vault.address, "https://")
    error_message = "external_vault.address must be an https:// URL."
  }

  validation {
    condition     = strcontains(var.external_vault.ca_chain_pem, "-----BEGIN CERTIFICATE-----")
    error_message = "external_vault.ca_chain_pem must be a PEM-encoded certificate bundle."
  }

  validation {
    condition     = var.external_vault.port >= 1 && var.external_vault.port <= 65535
    error_message = "external_vault.port must be between 1 and 65535."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.external_vault.auth_aws.mount_path))
    error_message = "external_vault.auth_aws.mount_path must contain only alphanumeric characters, underscores, and hyphens."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.external_vault.pki.mount_path))
    error_message = "external_vault.pki.mount_path must contain only alphanumeric characters, underscores, and hyphens."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.external_vault.kv.mount_path))
    error_message = "external_vault.kv.mount_path must contain only alphanumeric characters, underscores, and hyphens."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.external_vault.auth_aws.role_name))
    error_message = "external_vault.auth_aws.role_name must contain only alphanumeric characters, underscores, and hyphens."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.external_vault.pki.role_name))
    error_message = "external_vault.pki.role_name must contain only alphanumeric characters, underscores, and hyphens."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]+$", var.external_vault.kv.gossip_secret_path)) && !startswith(var.external_vault.kv.gossip_secret_path, "/") && !endswith(var.external_vault.kv.gossip_secret_path, "/")
    error_message = "external_vault.kv.gossip_secret_path must be a relative secret path without leading or trailing slashes."
  }

  validation {
    condition     = can(timeadd("2000-01-01T00:00:00Z", var.external_vault.pki.server_cert_ttl))
    error_message = "external_vault.pki.server_cert_ttl must be a Go duration string (e.g., \"24h\", \"1h30m\"). Valid Units: \"s\", \"m\", \"h\"."
  }
}

# Optional

variable "route53_zone" {
  type = object({
    zone_id = string
    name    = string
  })

  default     = null
  description = <<-EOT
    Route 53 hosted zone in which to create an A record pointing `consul_fqdn`
    at the module's NLB. Accepts the result of an `aws_route53_zone` data source
    directly. When `null` (default), no record is created and DNS must be
    configured out-of-band (typically a CNAME to the `nlb_dns_name` output).
    `consul_fqdn` must be within the supplied zone's namespace.
  EOT
}

variable "consul" {
  type = object({
    version    = optional(string, "1.22.8+ent")
    datacenter = optional(string, "dc1")
    ui         = optional(bool, true)

    log_level = optional(string, "info")
    log_json  = optional(bool, true)

    audit = optional(object({
      rotate_duration  = optional(string, "24h")
      rotate_max_files = optional(number, 15)
    }), {})

    telemetry = optional(object({
      prometheus_retention_time = optional(string, "24h")
      disable_hostname          = optional(bool, true)
    }), {})

    secretsmanager_secret = optional(object({
      license_name_prefix                  = optional(string, "consul-enterprise-license-")
      acl_management_token_name_prefix     = optional(string, "consul-enterprise-acl-management-token-")
      acl_agent_token_name_prefix          = optional(string, "consul-enterprise-acl-agent-token-")
      acl_snapshot_agent_token_name_prefix = optional(string, "consul-enterprise-acl-snapshot-agent-token-")
    }), {})
  })

  default     = {}
  description = "Consul Enterprise product configuration."

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\+ent(\\.fips1402)?$", var.consul.version))
    error_message = "consul.version must be a valid Consul Enterprise release version (e.g., 1.22.8+ent, 1.22.8+ent.fips1402)."
  }

  validation {
    condition     = can(regex("^[a-z0-9_-]+$", var.consul.datacenter))
    error_message = "consul.datacenter must contain only lowercase letters, digits, underscores, and hyphens."
  }

  validation {
    condition     = can(timeadd("2000-01-01T00:00:00Z", var.consul.audit.rotate_duration))
    error_message = "consul.audit.rotate_duration must be a Go duration string (e.g., \"24h\", \"1h30m\"). Valid Units: \"s\", \"m\", \"h\"."
  }

  validation {
    condition     = var.consul.audit.rotate_max_files >= 0
    error_message = "consul.audit.rotate_max_files must be 0 (keep all) or greater."
  }
}

variable "vault_agent" {
  type = object({
    version = optional(string, "1.21.4")
  })

  default     = {}
  description = <<-EOT
    Vault Agent installed on every Consul server to issue TLS certificates and
    render the gossip encryption key from the external Vault cluster. The
    community edition binary is sufficient for agent mode.
  EOT

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.vault_agent.version))
    error_message = "vault_agent.version must be a Vault community edition release version (e.g., 1.21.4)."
  }
}

variable "consul_snapshot" {
  type = object({
    aws_s3_bucket = optional(object({
      name_prefix   = optional(string, "consul-enterprise-snapshots-")
      force_destroy = optional(bool, false)
    }), {})
    s3_key_prefix = optional(string, "consul-snapshot")
    interval      = optional(string, "1h")
    retain        = optional(number, 72)
  })

  default     = {}
  description = "Consul Enterprise snapshot agent configuration."

  validation {
    condition     = can(timeadd("2000-01-01T00:00:00Z", var.consul_snapshot.interval))
    error_message = "consul_snapshot.interval must be a Go duration string (e.g., \"1h\", \"30m\"). Valid Units: \"s\", \"m\", \"h\"."
  }

  validation {
    condition     = var.consul_snapshot.retain >= 1
    error_message = "consul_snapshot.retain must be at least 1."
  }
}

variable "ami" {
  type = object({
    owners = optional(list(string), ["amazon"])
    name   = optional(string, "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-20260503")
  })

  default     = {}
  description = "AMI for EC2 instances. Must be Ubuntu or Debian-based. Accepts the result of an `aws_ami` data source directly."
}

variable "key_pair" {
  type = object({
    key_name = string
  })

  default     = null
  description = "EC2 key pair for SSH access. Accepts the result of an `aws_key_pair` data source directly."
}

variable "vpc" {
  type = object({
    name            = optional(string, "consul-enterprise-vpc")
    cidr            = optional(string, "10.0.0.0/16")
    private_subnets = optional(list(string), ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"])
    public_subnets  = optional(list(string), ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"])

    endpoints = optional(object({
      secretsmanager_name = optional(string, "consul-enterprise-secretsmanager-vpc-endpoint")
      ec2_name            = optional(string, "consul-enterprise-ec2-vpc-endpoint")
      s3_name             = optional(string, "consul-enterprise-s3-vpc-endpoint")

      security_group = optional(object({
        name_prefix = optional(string, "consul-enterprise-vpc-endpoints-")
        name        = optional(string, "consul-enterprise-vpc-endpoints")
      }), {})
    }), {})

    existing = optional(object({
      vpc_id             = string
      private_subnet_ids = list(string)
      public_subnet_ids  = list(string)
    }), null)
  })

  default     = {}
  description = <<-EOT
    VPC configuration. When `existing` is null (default), a new VPC is created
    using `cidr`, `private_subnets`, and `public_subnets`. When `existing` is
    set, those creation fields are ignored and the supplied VPC is used. The
    supplied VPC must have the required VPC endpoints configured.
  EOT

  validation {
    condition     = var.vpc.existing == null || (length(var.vpc.existing.private_subnet_ids) > 0 && length(var.vpc.existing.public_subnet_ids) > 0)
    error_message = "vpc.existing subnet ID lists must be non-empty when existing is set."
  }
}

variable "bastion" {
  type = object({
    name          = optional(string, "consul-enterprise-bastion-host")
    volume_name   = optional(string, "consul-enterprise-bastion-host-volume")
    instance_type = optional(string, "t3.micro")
    allowed_cidrs = optional(list(string), ["0.0.0.0/0"])

    security_group = optional(object({
      name_prefix = optional(string, "consul-enterprise-bastion-host-")
      name        = optional(string, "consul-enterprise-bastion-host")
    }), {})
  })

  default     = {}
  description = <<-EOT
    Bastion host configuration. `allowed_cidrs` defaults to `["0.0.0.0/0"]` for
    convenience; restrict to known ranges in any production deployment.
  EOT

  validation {
    condition     = alltrue([for cidr in var.bastion.allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "bastion.allowed_cidrs entries must be valid CIDR blocks."
  }
}

variable "compute" {
  type = object({
    instance_type = optional(string, "m6a.2xlarge")
    node_count    = optional(number, 5)

    root_disk = optional(object({
      volume_size = optional(number, 50)
      iops        = optional(number, 3000)
      throughput  = optional(number, 125)
    }), {})

    raft_data_disk = optional(object({
      volume_size = optional(number, 50)
      iops        = optional(number, 12000)
      throughput  = optional(number, 312)
    }), {})

    audit_disk = optional(object({
      volume_size = optional(number, 50)
      iops        = optional(number, 12000)
      throughput  = optional(number, 312)
    }), {})

    auto_join = optional(object({
      tag_key   = optional(string, "consul:server:retryjoin:autojoin")
      tag_value = optional(string, "consul-enterprise")
    }), {})

    security_group = optional(object({
      name_prefix = optional(string, "consul-enterprise-servers-")
      name        = optional(string, "consul-enterprise-servers")
    }), {})

    launch_template = optional(object({
      name_prefix = optional(string, "consul-enterprise-servers-")
      volume_name = optional(string, "consul-enterprise-volume")
    }), {})

    autoscaling_group = optional(object({
      name_prefix             = optional(string, "consul-enterprise-servers-")
      instance_name           = optional(string, "consul-enterprise-server")
      launch_template_version = optional(string, "$Default")
    }), {})
  })

  default     = {}
  description = "Configuration for the Consul Enterprise server EC2 instances and their EBS volumes."

  validation {
    condition     = contains([3, 5], var.compute.node_count)
    error_message = "compute.node_count must be 3 or 5 for Raft quorum."
  }

  validation {
    condition     = length(var.compute.auto_join.tag_value) > 0
    error_message = "compute.auto_join.tag_value must be a non-empty string to prevent accidentally joining an existing cluster."
  }

  validation {
    condition     = var.compute.root_disk.volume_size >= 20 && var.compute.root_disk.volume_size <= 65536
    error_message = "compute.root_disk.volume_size must be between 20 and 65536 GiB."
  }

  validation {
    condition     = var.compute.root_disk.iops >= 3000 && var.compute.root_disk.iops <= 80000
    error_message = "compute.root_disk.iops must be between 3000 and 80000."
  }

  validation {
    condition     = var.compute.root_disk.throughput >= 125 && var.compute.root_disk.throughput <= 2000
    error_message = "compute.root_disk.throughput must be between 125 and 2000 MiB/s."
  }

  validation {
    condition     = var.compute.root_disk.iops <= var.compute.root_disk.volume_size * 500
    error_message = "compute.root_disk.iops cannot exceed compute.root_disk.volume_size * 500."
  }

  validation {
    condition     = var.compute.root_disk.throughput <= var.compute.root_disk.iops * 0.25
    error_message = "compute.root_disk.throughput cannot exceed compute.root_disk.iops * 0.25."
  }

  validation {
    condition     = var.compute.raft_data_disk.volume_size >= 1 && var.compute.raft_data_disk.volume_size <= 65536
    error_message = "compute.raft_data_disk.volume_size must be between 1 and 65536 GiB."
  }

  validation {
    condition     = var.compute.raft_data_disk.iops >= 3000 && var.compute.raft_data_disk.iops <= 80000
    error_message = "compute.raft_data_disk.iops must be between 3000 and 80000."
  }

  validation {
    condition     = var.compute.raft_data_disk.throughput >= 125 && var.compute.raft_data_disk.throughput <= 2000
    error_message = "compute.raft_data_disk.throughput must be between 125 and 2000 MiB/s."
  }

  validation {
    condition     = var.compute.raft_data_disk.iops <= var.compute.raft_data_disk.volume_size * 500
    error_message = "compute.raft_data_disk.iops cannot exceed compute.raft_data_disk.volume_size * 500."
  }

  validation {
    condition     = var.compute.raft_data_disk.throughput <= var.compute.raft_data_disk.iops * 0.25
    error_message = "compute.raft_data_disk.throughput cannot exceed compute.raft_data_disk.iops * 0.25."
  }

  validation {
    condition     = var.compute.audit_disk.volume_size >= 1 && var.compute.audit_disk.volume_size <= 65536
    error_message = "compute.audit_disk.volume_size must be between 1 and 65536 GiB."
  }

  validation {
    condition     = var.compute.audit_disk.iops >= 3000 && var.compute.audit_disk.iops <= 80000
    error_message = "compute.audit_disk.iops must be between 3000 and 80000."
  }

  validation {
    condition     = var.compute.audit_disk.throughput >= 125 && var.compute.audit_disk.throughput <= 2000
    error_message = "compute.audit_disk.throughput must be between 125 and 2000 MiB/s."
  }

  validation {
    condition     = var.compute.audit_disk.iops <= var.compute.audit_disk.volume_size * 500
    error_message = "compute.audit_disk.iops cannot exceed compute.audit_disk.volume_size * 500."
  }

  validation {
    condition     = var.compute.audit_disk.throughput <= var.compute.audit_disk.iops * 0.25
    error_message = "compute.audit_disk.throughput cannot exceed compute.audit_disk.iops * 0.25."
  }

  validation {
    condition     = contains(["$Default", "$Latest"], var.compute.autoscaling_group.launch_template_version)
    error_message = "Must be \"$Default\" or \"$Latest\"."
  }
}

variable "nlb" {
  type = object({
    name_prefix         = optional(string, "consul")
    internal            = optional(bool, true)
    api_allowed_cidrs   = optional(list(string), [])
    deletion_protection = optional(bool, true)

    lb_target_group = optional(object({
      name_prefix = optional(string, "consul")
    }), {})
  })

  default     = {}
  description = <<-EOT
    NLB configuration for the Consul HTTPS API. `api_allowed_cidrs` is only
    effective when `internal` is `false`.
  EOT

  validation {
    condition     = length(var.nlb.name_prefix) <= 6
    error_message = "nlb.name_prefix must be 6 characters or fewer."
  }

  validation {
    condition     = length(var.nlb.lb_target_group.name_prefix) <= 6
    error_message = "nlb.lb_target_group.name_prefix must be 6 characters or fewer."
  }

  validation {
    condition     = alltrue([for cidr in var.nlb.api_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "nlb.api_allowed_cidrs entries must be valid CIDR blocks."
  }
}

variable "iam_role" {
  type = object({
    name = optional(string, "ConsulEnterpriseServerRole")
    path = optional(string, "/")

    instance_profile = optional(object({
      name = optional(string, "ConsulEnterpriseServerInstanceProfile")
      path = optional(string, "/")
    }), {})

    inline_policy_names = optional(object({
      secrets_manager_read       = optional(string, "SecretsManagerReadAccess")
      secrets_manager_read_write = optional(string, "SecretsManagerReadWriteAccess")
      s3_object_read_write       = optional(string, "S3ObjectReadWriteAccess")
      s3_bucket_list             = optional(string, "S3BucketListAccess")
      ec2_describe               = optional(string, "EC2DescribeAccess")
      ssm_read_write             = optional(string, "SSMReadWriteAccess")
    }), {})
  })

  default     = {}
  description = <<-EOT
    IAM role configuration for the Consul Enterprise EC2 instances. The module
    creates one role with several inline policies attached and an associated
    instance profile. The role's ARN is exported as `iam_role_arn` and must be
    bound to the external Vault AWS auth role.
  EOT

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]+$", var.iam_role.name))
    error_message = "IAM role name must contain only alphanumeric or '+=,.@-_' characters."
  }

  validation {
    condition     = length(var.iam_role.name) >= 1 && length(var.iam_role.name) <= 64
    error_message = "IAM role name must be 1-64 characters."
  }

  validation {
    condition     = startswith(var.iam_role.path, "/") && endswith(var.iam_role.path, "/")
    error_message = "IAM role path must start and end with '/'."
  }

  validation {
    condition     = !can(regex("[[:space:]]", var.iam_role.path))
    error_message = "IAM role path must not contain spaces, tabs, or newlines."
  }

  validation {
    condition     = can(regex("^[[:print:]/]+$", var.iam_role.path))
    error_message = "IAM role path must contain only printable ASCII characters."
  }
  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]+$", var.iam_role.instance_profile.name))
    error_message = "IAM instance profile name must contain only alphanumeric or '+=,.@-_' characters."
  }

  validation {
    condition     = length(var.iam_role.instance_profile.name) >= 1 && length(var.iam_role.instance_profile.name) <= 64
    error_message = "IAM instance profile name must be 1-64 characters."
  }

  validation {
    condition     = startswith(var.iam_role.instance_profile.path, "/") && endswith(var.iam_role.instance_profile.path, "/")
    error_message = "IAM instance profile path must start and end with '/'."
  }

  validation {
    condition     = !can(regex("[[:space:]]", var.iam_role.instance_profile.path))
    error_message = "IAM instance profile path must not contain spaces, tabs, or newlines."
  }

  validation {
    condition     = can(regex("^[[:print:]/]+$", var.iam_role.instance_profile.path))
    error_message = "IAM instance profile path must contain only printable ASCII characters."
  }

  validation {
    condition = alltrue([
      for policy_name in values(var.iam_role.inline_policy_names) :
      can(regex("^[A-Za-z0-9+=,.@_-]+$", policy_name))
    ])
    error_message = "IAM inline policy names must contain only alphanumeric or '+=,.@-_' characters."
  }

  validation {
    condition = alltrue([
      for policy_name in values(var.iam_role.inline_policy_names) :
      length(policy_name) >= 1 && length(policy_name) <= 64
    ])
    error_message = "IAM inline policy names must be 1-64 characters."
  }
}

variable "bootstrap" {
  type = object({
    ssm_parameter = optional(object({
      consul_cluster_state_name = optional(string, "/consul-enterprise/bootstrap/cluster/state")
      instance_id_name          = optional(string, "/consul-enterprise/bootstrap/instance/id")
      pki_ca_chain_name         = optional(string, "/consul-enterprise/bootstrap/pki/ca-chain")
    }), {})
  })

  default     = {}
  description = <<-EOT
    AWS resources used only during the Consul bootstrap ceremony. SSM
    parameters hold non-sensitive coordination state shared between nodes.
  EOT
}
