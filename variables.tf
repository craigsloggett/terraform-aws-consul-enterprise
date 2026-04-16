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

variable "consul_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}

variable "ec2_key_pair_name" {
  type        = string
  description = "Name of an existing EC2 key pair for SSH access."
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
    Secrets Manager and EC2 (Interface), S3 (Gateway).
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

variable "consul_server_instance_type" {
  type        = string
  description = "EC2 instance type for Consul server nodes."
  default     = "m5.large"
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
}

variable "vault_version" {
  type        = string
  description = "Vault CLI release version installed on Consul server nodes for bootstrap."
  default     = "1.19.4"
}

variable "consul_datacenter" {
  type        = string
  description = "Consul datacenter name."
  default     = "dc1"
}

variable "nomad_server_service_name" {
  description = "Consul service name Nomad servers will register as."
  type        = string
  default     = "nomad-server"
}

variable "nomad_client_service_name" {
  description = "Consul service name Nomad clients will register as."
  type        = string
  default     = "nomad-client"
}

variable "nomad_snapshot_service_name" {
  description = "Consul service name the Nomad snapshot agent will register as."
  type        = string
  default     = "nomad-snapshot"
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

# Vault

variable "vault_fqdn" {
  type        = string
  description = "Vault server FQDN. Used for the AIA URLs on the Consul PKI intermediate and as the default IAM server ID header value for AWS auth anti-replay."
}

variable "vault_ca_cert" {
  type        = string
  description = "PEM-encoded CA chain that signed the Vault server certificate. Written to disk on Consul servers and used as VAULT_CACERT during bootstrap. Leave empty to skip TLS verification when calling Vault (not recommended)."
  default     = ""
}

variable "vault_iam_server_id_header_value" {
  type        = string
  description = "Value of the X-Vault-AWS-IAM-Server-ID header passed during AWS auth login. Must match what is configured on the Vault AWS auth method (auth/aws/config/client iam_server_id_header_value=...). Defaults to vault_fqdn when null."
  default     = null
}

variable "vault_pki_root_backend" {
  type        = string
  description = "Name of the existing Vault PKI root mount that signs the Consul intermediate CA."
  default     = "pki_root"
}

variable "vault_pki_organization" {
  type        = string
  description = "Organization embedded in the Consul intermediate CA when signed by the root."
  default     = null
}

variable "vault_pki_country" {
  type        = string
  description = "Country embedded in the Consul intermediate CA when signed by the root."
  default     = null
}
