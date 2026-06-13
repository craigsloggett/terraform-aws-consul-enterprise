# HashiCorp Consul Enterprise Terraform Module

Terraform module which deploys a Consul Enterprise cluster on AWS with Raft integrated storage and TLS managed by an external Vault cluster.

A Vault Agent on every Consul server authenticates to Vault with the AWS auth method, issues the server TLS certificate from Vault PKI before Consul starts, renders the gossip encryption key from KV v2, and renews the certificate for the life of the node. The module makes no configuration changes to Vault.

## Vault Prerequisites

The external Vault cluster must be reachable over HTTPS from the module's private subnets and configured ahead of time with:

- An AWS auth method at `external_vault.auth_aws.mount_path` with a role named `external_vault.auth_aws.role_name`, `auth_type = "iam"`, bound to this module's `iam_role_arn` output.
- A PKI mount at `external_vault.pki.mount_path` with a role named `external_vault.pki.role_name` permitting certificates with the common name `consul_fqdn`, the alt names `server.<datacenter>.consul` and `localhost`, the IP SAN `127.0.0.1`, and a TTL of at least `external_vault.pki.server_cert_ttl`.
- A KV v2 mount at `external_vault.kv.mount_path` holding a 32-byte base64 gossip encryption key at `external_vault.kv.gossip_secret_path` under the field `external_vault.kv.gossip_key_field`.
- A token policy on the AWS auth role allowing `create`/`update` on the PKI role's issue path and `read` on the gossip key.
- The Vault CA chain, passed to the module as `external_vault.ca_chain_pem`.

The example in `examples/vault-managed-pki` creates all of these with the Vault provider.

Service mesh is out of scope: the gRPC listeners are disabled and no Connect CA is configured. Re-enable `grpc_tls` in the server configuration if consul-dataplane consumers are added later.

<!-- BEGIN_TF_DOCS -->
## Usage

### main.tf
```hcl
module "consul" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/craigsloggett/terraform-aws-consul-enterprise"

  consul_enterprise_license = var.consul_enterprise_license
  consul_fqdn               = var.consul_fqdn

  external_vault = {
    address      = var.vault_address
    ca_chain_pem = var.vault_ca_chain_pem
  }

  nlb = {
    # Deletion protection blocks `terraform destroy` of this example.
    deletion_protection = false
  }
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami"></a> [ami](#input\_ami) | AMI for EC2 instances. Must be Ubuntu or Debian-based. Accepts the result of an `aws_ami` data source directly. | <pre>object({<br/>    owners = optional(list(string), ["amazon"])<br/>    name   = optional(string, "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-20260503")<br/>  })</pre> | `{}` | no |
| <a name="input_bastion"></a> [bastion](#input\_bastion) | Bastion host configuration. `allowed_cidrs` defaults to `["0.0.0.0/0"]` for<br/>convenience; restrict to known ranges in any production deployment. | <pre>object({<br/>    name          = optional(string, "consul-enterprise-bastion-host")<br/>    volume_name   = optional(string, "consul-enterprise-bastion-host-volume")<br/>    instance_type = optional(string, "t3.micro")<br/>    allowed_cidrs = optional(list(string), ["0.0.0.0/0"])<br/><br/>    security_group = optional(object({<br/>      name_prefix = optional(string, "consul-enterprise-bastion-host-")<br/>      name        = optional(string, "consul-enterprise-bastion-host")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_bootstrap"></a> [bootstrap](#input\_bootstrap) | AWS resources used only during the Consul bootstrap ceremony. SSM<br/>parameters hold non-sensitive coordination state shared between nodes. | <pre>object({<br/>    ssm_parameter = optional(object({<br/>      consul_cluster_state_name = optional(string, "/consul-enterprise/bootstrap/cluster/state")<br/>      instance_id_name          = optional(string, "/consul-enterprise/bootstrap/instance/id")<br/>      pki_ca_chain_name         = optional(string, "/consul-enterprise/bootstrap/pki/ca-chain")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_compute"></a> [compute](#input\_compute) | Configuration for the Consul Enterprise server EC2 instances and their EBS volumes. | <pre>object({<br/>    instance_type = optional(string, "m6a.2xlarge")<br/>    node_count    = optional(number, 5)<br/><br/>    root_disk = optional(object({<br/>      volume_size = optional(number, 50)<br/>      iops        = optional(number, 3000)<br/>      throughput  = optional(number, 125)<br/>    }), {})<br/><br/>    raft_data_disk = optional(object({<br/>      volume_size = optional(number, 50)<br/>      iops        = optional(number, 12000)<br/>      throughput  = optional(number, 312)<br/>    }), {})<br/><br/>    audit_disk = optional(object({<br/>      volume_size = optional(number, 50)<br/>      iops        = optional(number, 12000)<br/>      throughput  = optional(number, 312)<br/>    }), {})<br/><br/>    auto_join = optional(object({<br/>      tag_key   = optional(string, "consul:server:retryjoin:autojoin")<br/>      tag_value = optional(string, "consul-enterprise")<br/>    }), {})<br/><br/>    security_group = optional(object({<br/>      name_prefix = optional(string, "consul-enterprise-servers-")<br/>      name        = optional(string, "consul-enterprise-servers")<br/>    }), {})<br/><br/>    launch_template = optional(object({<br/>      name_prefix = optional(string, "consul-enterprise-servers-")<br/>      volume_name = optional(string, "consul-enterprise-volume")<br/>    }), {})<br/><br/>    autoscaling_group = optional(object({<br/>      name_prefix             = optional(string, "consul-enterprise-servers-")<br/>      instance_name           = optional(string, "consul-enterprise-server")<br/>      launch_template_version = optional(string, "$Default")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_consul"></a> [consul](#input\_consul) | Consul Enterprise product configuration. | <pre>object({<br/>    version    = optional(string, "1.22.8+ent")<br/>    datacenter = optional(string, "dc1")<br/>    ui         = optional(bool, true)<br/><br/>    log_level = optional(string, "info")<br/>    log_json  = optional(bool, true)<br/><br/>    audit = optional(object({<br/>      rotate_duration  = optional(string, "24h")<br/>      rotate_max_files = optional(number, 15)<br/>    }), {})<br/><br/>    telemetry = optional(object({<br/>      prometheus_retention_time = optional(string, "24h")<br/>      disable_hostname          = optional(bool, true)<br/>    }), {})<br/><br/>    secretsmanager_secret = optional(object({<br/>      license_name_prefix                  = optional(string, "consul-enterprise-license-")<br/>      acl_management_token_name_prefix     = optional(string, "consul-enterprise-acl-management-token-")<br/>      acl_agent_token_name_prefix          = optional(string, "consul-enterprise-acl-agent-token-")<br/>      acl_snapshot_agent_token_name_prefix = optional(string, "consul-enterprise-acl-snapshot-agent-token-")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_consul_enterprise_license"></a> [consul\_enterprise\_license](#input\_consul\_enterprise\_license) | Consul Enterprise license string. | `string` | n/a | yes |
| <a name="input_consul_fqdn"></a> [consul\_fqdn](#input\_consul\_fqdn) | Fully qualified domain name in presentation form for the Consul Enterprise<br/>cluster. Used as the TLS certificate common name and the public API<br/>endpoint behind the NLB. | `string` | n/a | yes |
| <a name="input_consul_snapshot"></a> [consul\_snapshot](#input\_consul\_snapshot) | Consul Enterprise snapshot agent configuration. | <pre>object({<br/>    aws_s3_bucket = optional(object({<br/>      name_prefix   = optional(string, "consul-enterprise-snapshots-")<br/>      force_destroy = optional(bool, false)<br/>    }), {})<br/>    s3_key_prefix = optional(string, "consul-snapshot")<br/>    interval      = optional(string, "1h")<br/>    retain        = optional(number, 72)<br/>  })</pre> | `{}` | no |
| <a name="input_external_vault"></a> [external\_vault](#input\_external\_vault) | Pre-existing Vault cluster that manages PKI and the gossip encryption key<br/>for the Consul servers. The module makes no configuration changes to this<br/>cluster; a Vault Agent on every Consul server authenticates with the AWS<br/>auth method at `auth_aws.mount_path` using `auth_aws.role_name` (which must<br/>be bound to this module's `iam_role_arn` output), issues the server TLS<br/>certificate from the PKI role at `pki.mount_path`/issue/`pki.role_name`,<br/>and reads the gossip encryption key from the KV v2 secret at<br/>`kv.mount_path`/`kv.gossip_secret_path` under `kv.gossip_key_field`.<br/>`port` only feeds the security group egress rule; `address` carries the<br/>port the agent connects to. | <pre>object({<br/>    address         = string<br/>    port            = optional(number, 8200)<br/>    tls_server_name = optional(string, "")<br/>    ca_chain_pem    = string<br/><br/>    auth_aws = optional(object({<br/>      mount_path   = optional(string, "aws")<br/>      role_name    = optional(string, "consul-server")<br/>      header_value = optional(string, "")<br/>    }), {})<br/><br/>    pki = optional(object({<br/>      mount_path      = optional(string, "pki_consul")<br/>      role_name       = optional(string, "consul-server")<br/>      server_cert_ttl = optional(string, "24h")<br/>    }), {})<br/><br/>    kv = optional(object({<br/>      mount_path         = optional(string, "kv")<br/>      gossip_secret_path = optional(string, "consul/gossip")<br/>      gossip_key_field   = optional(string, "key")<br/>    }), {})<br/>  })</pre> | n/a | yes |
| <a name="input_iam_role"></a> [iam\_role](#input\_iam\_role) | IAM role configuration for the Consul Enterprise EC2 instances. The module<br/>creates one role with several inline policies attached and an associated<br/>instance profile. The role's ARN is exported as `iam_role_arn` and must be<br/>bound to the external Vault AWS auth role. | <pre>object({<br/>    name = optional(string, "ConsulEnterpriseServerRole")<br/>    path = optional(string, "/")<br/><br/>    instance_profile = optional(object({<br/>      name = optional(string, "ConsulEnterpriseServerInstanceProfile")<br/>      path = optional(string, "/")<br/>    }), {})<br/><br/>    inline_policy_names = optional(object({<br/>      secrets_manager_read       = optional(string, "SecretsManagerReadAccess")<br/>      secrets_manager_read_write = optional(string, "SecretsManagerReadWriteAccess")<br/>      s3_object_read_write       = optional(string, "S3ObjectReadWriteAccess")<br/>      s3_bucket_list             = optional(string, "S3BucketListAccess")<br/>      ec2_describe               = optional(string, "EC2DescribeAccess")<br/>      ssm_read_write             = optional(string, "SSMReadWriteAccess")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_key_pair"></a> [key\_pair](#input\_key\_pair) | EC2 key pair for SSH access. Accepts the result of an `aws_key_pair` data source directly. | <pre>object({<br/>    key_name = string<br/>  })</pre> | `null` | no |
| <a name="input_nlb"></a> [nlb](#input\_nlb) | NLB configuration for the Consul HTTPS API. `api_allowed_cidrs` is only<br/>effective when `internal` is `false`. | <pre>object({<br/>    name_prefix         = optional(string, "consul")<br/>    internal            = optional(bool, true)<br/>    api_allowed_cidrs   = optional(list(string), [])<br/>    deletion_protection = optional(bool, true)<br/><br/>    lb_target_group = optional(object({<br/>      name_prefix = optional(string, "consul")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_route53_zone"></a> [route53\_zone](#input\_route53\_zone) | Route 53 hosted zone in which to create an A record pointing `consul_fqdn`<br/>at the module's NLB. Accepts the result of an `aws_route53_zone` data source<br/>directly. When `null` (default), no record is created and DNS must be<br/>configured out-of-band (typically a CNAME to the `nlb_dns_name` output).<br/>`consul_fqdn` must be within the supplied zone's namespace. | <pre>object({<br/>    zone_id = string<br/>    name    = string<br/>  })</pre> | `null` | no |
| <a name="input_vault_agent"></a> [vault\_agent](#input\_vault\_agent) | Vault Agent installed on every Consul server to issue TLS certificates and<br/>render the gossip encryption key from the external Vault cluster. The<br/>community edition binary is sufficient for agent mode. | <pre>object({<br/>    version = optional(string, "1.21.4")<br/>  })</pre> | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration. When `existing` is null (default), a new VPC is created<br/>using `cidr`, `private_subnets`, and `public_subnets`. When `existing` is<br/>set, those creation fields are ignored and the supplied VPC is used. The<br/>supplied VPC must have the required VPC endpoints configured. | <pre>object({<br/>    name            = optional(string, "consul-enterprise-vpc")<br/>    cidr            = optional(string, "10.0.0.0/16")<br/>    private_subnets = optional(list(string), ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"])<br/>    public_subnets  = optional(list(string), ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"])<br/><br/>    endpoints = optional(object({<br/>      secretsmanager_name = optional(string, "consul-enterprise-secretsmanager-vpc-endpoint")<br/>      ec2_name            = optional(string, "consul-enterprise-ec2-vpc-endpoint")<br/>      s3_name             = optional(string, "consul-enterprise-s3-vpc-endpoint")<br/><br/>      security_group = optional(object({<br/>        name_prefix = optional(string, "consul-enterprise-vpc-endpoints-")<br/>        name        = optional(string, "consul-enterprise-vpc-endpoints")<br/>      }), {})<br/>    }), {})<br/><br/>    existing = optional(object({<br/>      vpc_id             = string<br/>      private_subnet_ids = list(string)<br/>      public_subnet_ids  = list(string)<br/>    }), null)<br/>  })</pre> | `{}` | no |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_autoscaling_group.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_iam_instance_profile.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ec2_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_bucket_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3_object_read_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.secrets_manager_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.secrets_manager_read_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ssm_read_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.consul_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.acl_agent_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.acl_management_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.acl_snapshot_agent_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.license](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.license](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.consul_enterprise_servers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.bootstrap_consul_cluster_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.bootstrap_consul_pki_ca_chain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.bootstrap_instance_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_endpoint.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.bastion_dns_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.bastion_dns_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.bastion_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.bastion_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.bastion_ntp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.bastion_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_dns_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_dns_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_external_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_ntp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_serf_lan_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_serf_lan_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_serf_wan_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_serf_wan_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_server_rpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.bastion_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_dns_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_dns_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_https_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_https_api_external](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_serf_lan_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_serf_lan_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_serf_wan_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_serf_wan_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_enterprise_server_rpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vpc_endpoints_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ec2_instance_type.compute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.deny_insecure_transport](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_bucket_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_object_read_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets_manager_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets_manager_read_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ssm_read_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_acl_management_token_secret_arn"></a> [acl\_management\_token\_secret\_arn](#output\_acl\_management\_token\_secret\_arn) | Secrets Manager ARN holding the ACL management token created by `consul acl bootstrap`. |
| <a name="output_ami_name"></a> [ami\_name](#output\_ami\_name) | Name of the AMI used for EC2 instances. |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the Consul Enterprise Auto Scaling Group. |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_bootstrap_consul_cluster_state_ssm_parameter_name"></a> [bootstrap\_consul\_cluster\_state\_ssm\_parameter\_name](#output\_bootstrap\_consul\_cluster\_state\_ssm\_parameter\_name) | SSM Parameter for the bootstrap initialization state flag. |
| <a name="output_bootstrap_consul_pki_ca_chain_ssm_parameter_name"></a> [bootstrap\_consul\_pki\_ca\_chain\_ssm\_parameter\_name](#output\_bootstrap\_consul\_pki\_ca\_chain\_ssm\_parameter\_name) | SSM Parameter holding the PEM CA chain that signs the Consul server certificates. |
| <a name="output_bootstrap_instance_id_ssm_parameter_name"></a> [bootstrap\_instance\_id\_ssm\_parameter\_name](#output\_bootstrap\_instance\_id\_ssm\_parameter\_name) | SSM Parameter for the elected bootstrap node EC2 instance ID. |
| <a name="output_consul_datacenter"></a> [consul\_datacenter](#output\_consul\_datacenter) | Consul datacenter name. |
| <a name="output_consul_snapshot_aws_s3_bucket_name"></a> [consul\_snapshot\_aws\_s3\_bucket\_name](#output\_consul\_snapshot\_aws\_s3\_bucket\_name) | Name of the S3 bucket for Consul Enterprise snapshots. |
| <a name="output_consul_url"></a> [consul\_url](#output\_consul\_url) | URL of the Consul Enterprise cluster. |
| <a name="output_consul_version"></a> [consul\_version](#output\_consul\_version) | Consul Enterprise version deployed. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the Consul server IAM role. Bind this to the external Vault AWS auth role so the Vault Agents can authenticate. |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | AWS-assigned DNS name of the Consul NLB. Use this as the CNAME target when DNS is managed outside Route 53. |
| <a name="output_nlb_zone_id"></a> [nlb\_zone\_id](#output\_nlb\_zone\_id) | Hosted zone ID of the Consul NLB. Use this when creating a Route 53 alias record outside this module. |
<!-- END_TF_DOCS -->
