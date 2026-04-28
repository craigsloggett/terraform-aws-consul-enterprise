# Required

variable "project_name" {
  type        = string
  description = "Name prefix for all resources."

  validation {
    condition     = length(var.project_name) <= 16
    error_message = "Must be 16 characters or fewer to fit within the 63-character S3 bucket name limit."
  }
}

variable "route53_zone" {
  type = object({
    zone_id = string
    name    = string
  })
  description = "Route 53 hosted zone for the Consul DNS record."
}

variable "consul_enterprise_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}

variable "consul_ca_cert_pem" {
  type        = string
  description = "PEM-encoded CA certificate trusted by the Consul cluster."
  sensitive   = true
}

variable "consul_server_cert_pem" {
  type        = string
  description = "PEM-encoded TLS certificate for Consul server nodes."
  sensitive   = true
}

variable "consul_server_key_pem" {
  type        = string
  description = "PEM-encoded TLS private key for Consul server nodes."
  sensitive   = true
}

variable "consul_gossip_key" {
  type        = string
  description = "Base64-encoded 32-byte gossip encryption key for the Consul cluster."
  sensitive   = true
}

variable "ec2_key_pair_name" {
  type        = string
  description = "Name of an existing EC2 key pair for SSH access."
}

# Vault Integration

variable "vault_address" {
  type        = string
  description = "Address of the Vault cluster reachable from Consul nodes (e.g. https://vault.example.com:8200)."
}

variable "vault_ca_cert_pem" {
  type        = string
  description = "PEM CA bundle used by Vault Agent to verify the Vault TLS endpoint."
  sensitive   = true
}

variable "vault_aws_auth_role" {
  type        = string
  description = "Name of the Vault AWS IAM auth role bound to the Consul server instance role."
}

variable "vault_pki_mount_path" {
  type        = string
  description = "Path of the Consul-specific Vault PKI mount that issues server certificates."
  default     = "pki_consul_int"
}

variable "vault_pki_role_name" {
  type        = string
  description = "Name of the Vault PKI role used to issue Consul server certificates."
  default     = "consul-server"
}

variable "vault_agent_version" {
  type        = string
  description = "Version of the Vault binary installed on each node and run as Vault Agent."
}

variable "iam_role_name" {
  type        = string
  description = "Fixed name for the Consul server IAM role. When null (default), a name_prefix derived from project_name is used. Set this to coordinate with a Vault AWS auth role binding."
  default     = null
}

# General

variable "common_tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

# VPC

variable "existing_vpc" {
  type = object({
    vpc_id             = string
    private_subnet_ids = list(string)
    public_subnet_ids  = list(string)
  })
  default     = null
  description = <<-EOT
    Existing VPC to deploy into. When null (default), a new VPC is created.
    The existing VPC must already have the required VPC endpoints:
    Secrets Manager, SSM, and EC2 (Interface), S3 (Gateway).
  EOT

  validation {
    condition     = var.existing_vpc == null || (length(var.existing_vpc.private_subnet_ids) > 0 && length(var.existing_vpc.public_subnet_ids) > 0)
    error_message = "existing_vpc subnet ID lists must be non-empty."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "vpc_private_subnets" {
  type        = list(string)
  description = "Private subnet CIDR blocks."
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_public_subnets" {
  type        = list(string)
  description = "Public subnet CIDR blocks."
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# EC2

variable "ec2_ami" {
  type = object({
    id   = string
    name = string
  })
  description = "AMI to use for EC2 instances. Must be Ubuntu or Debian-based."
}

variable "consul_node_count" {
  type        = number
  description = "Number of Consul server nodes in the cluster. Must be 3 or 5 for Raft quorum."
  default     = 3

  validation {
    condition     = contains([3, 5], var.consul_node_count)
    error_message = "Must be 3 or 5."
  }
}

variable "consul_server_instance_type" {
  type        = string
  description = "EC2 instance type for Consul server nodes."
  default     = "m5.large"
}

variable "root_volume_size" {
  type        = number
  description = "Size in GiB of the root EBS volume for Consul nodes."
  default     = 50

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "Root volume must be at least 20 GiB."
  }
}

variable "consul_ebs_volume_size" {
  type        = number
  description = "Size in GiB of the EBS volume for Consul Raft storage."
  default     = 100
}

variable "bastion_instance_type" {
  type        = string
  description = "EC2 instance type for the bastion host."
  default     = "t3.micro"
}

variable "bastion_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to the bastion host. Defaults to 0.0.0.0/0 for convenience; restrict to known ranges in any production deployment."
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.bastion_allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All entries must be valid CIDR blocks."
  }
}

# Consul

variable "consul_subdomain" {
  type        = string
  description = "Subdomain for the Consul DNS record."
  default     = "consul"
}

variable "consul_version" {
  type        = string
  description = "Consul Enterprise release version (e.g., 1.22.6+ent)."
  default     = "1.22.6+ent"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+\\+ent$", var.consul_version))
    error_message = "Must be a valid Consul Enterprise release version (e.g., 1.22.6+ent)."
  }
}

variable "consul_datacenter" {
  type        = string
  description = "Consul datacenter name."
  default     = "dc1"
}

# NLB

variable "nlb_internal" {
  type        = bool
  description = "Whether the NLB is internal."
  default     = true
}

variable "consul_api_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the Consul API (port 8501) from outside the VPC. Only effective when nlb_internal is false."
  default     = []
}

# Snapshots

variable "consul_snapshot_interval" {
  type        = string
  description = "Interval between automated Raft snapshots (e.g., 1h, 30m, 24h)."
  default     = "1h"

  validation {
    condition     = can(regex("^\\d+[hms]$", var.consul_snapshot_interval))
    error_message = "Must be a valid Go duration string (e.g., 1h, 30m, 24h)."
  }
}

variable "consul_snapshot_retain" {
  type        = number
  description = "Number of automated Raft snapshots to retain in S3."
  default     = 72

  validation {
    condition     = var.consul_snapshot_retain >= 1
    error_message = "Must retain at least 1 snapshot."
  }
}
