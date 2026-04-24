# HashiCorp Consul Enterprise Terraform Module
A Terraform module for deploying HashiCorp Consul Enterprise on AWS.

<!-- BEGIN_TF_DOCS -->
## Usage

### main.tf
```hcl
module "consul" {
  source = "../.."

  project_name              = var.project_name
  consul_enterprise_license = var.consul_enterprise_license
  ec2_key_pair_name         = "example"

  ec2_ami = {
    id   = "ami-0example"
    name = "ubuntu-example"
  }

  route53_zone = {
    zone_id = "Z0000000000000"
    name    = "example.com"
  }

  vault_url           = "https://vault.example.com"
  vault_iam_role_name = "vault-server"
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | ~> 5.8 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.13 |
| <a name="provider_vault"></a> [vault](#provider\_vault) | ~> 5.8 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bastion_allowed_cidrs"></a> [bastion\_allowed\_cidrs](#input\_bastion\_allowed\_cidrs) | CIDR blocks allowed to SSH to the bastion host. Defaults to 0.0.0.0/0 for convenience; restrict to known ranges in any production deployment. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_bastion_instance_type"></a> [bastion\_instance\_type](#input\_bastion\_instance\_type) | EC2 instance type for the bastion host. | `string` | `"t3.micro"` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_consul_api_allowed_cidrs"></a> [consul\_api\_allowed\_cidrs](#input\_consul\_api\_allowed\_cidrs) | CIDR blocks allowed to reach the Consul API (port 8501) from outside the VPC. Only effective when nlb\_internal is false. | `list(string)` | `[]` | no |
| <a name="input_consul_datacenter"></a> [consul\_datacenter](#input\_consul\_datacenter) | Consul datacenter name. | `string` | `"dc1"` | no |
| <a name="input_consul_ebs_volume_size"></a> [consul\_ebs\_volume\_size](#input\_consul\_ebs\_volume\_size) | Size in GiB of the EBS volume for Consul Raft storage. | `number` | `100` | no |
| <a name="input_consul_enterprise_license"></a> [consul\_enterprise\_license](#input\_consul\_enterprise\_license) | Consul Enterprise license string. | `string` | n/a | yes |
| <a name="input_consul_node_count"></a> [consul\_node\_count](#input\_consul\_node\_count) | Number of Consul server nodes in the cluster. Must be 3 or 5 for Raft quorum. | `number` | `3` | no |
| <a name="input_consul_pki_signed_intermediate_wait_timeout_seconds"></a> [consul\_pki\_signed\_intermediate\_wait\_timeout\_seconds](#input\_consul\_pki\_signed\_intermediate\_wait\_timeout\_seconds) | Maximum seconds the bootstrap node waits for the signed intermediate certificate to appear in Secrets Manager. | `number` | `1800` | no |
| <a name="input_consul_server_cert_ttl"></a> [consul\_server\_cert\_ttl](#input\_consul\_server\_cert\_ttl) | TTL for Consul server certificates issued by Vault. | `string` | `"24h"` | no |
| <a name="input_consul_server_instance_type"></a> [consul\_server\_instance\_type](#input\_consul\_server\_instance\_type) | EC2 instance type for Consul server nodes. | `string` | `"m5.large"` | no |
| <a name="input_consul_snapshot_interval"></a> [consul\_snapshot\_interval](#input\_consul\_snapshot\_interval) | Interval between automated Raft snapshots (e.g., 1h, 30m, 24h). | `string` | `"1h"` | no |
| <a name="input_consul_snapshot_retain"></a> [consul\_snapshot\_retain](#input\_consul\_snapshot\_retain) | Number of automated Raft snapshots to retain in S3. | `number` | `72` | no |
| <a name="input_consul_subdomain"></a> [consul\_subdomain](#input\_consul\_subdomain) | Subdomain for the Consul DNS record. | `string` | `"consul"` | no |
| <a name="input_consul_version"></a> [consul\_version](#input\_consul\_version) | Consul Enterprise release version (e.g., 1.22.6+ent). | `string` | `"1.22.6+ent"` | no |
| <a name="input_ec2_ami"></a> [ec2\_ami](#input\_ec2\_ami) | AMI to use for EC2 instances. Must be Ubuntu or Debian-based. | <pre>object({<br/>    id   = string<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_ec2_key_pair_name"></a> [ec2\_key\_pair\_name](#input\_ec2\_key\_pair\_name) | Name of an existing EC2 key pair for SSH access. | `string` | n/a | yes |
| <a name="input_existing_vpc"></a> [existing\_vpc](#input\_existing\_vpc) | Existing VPC to deploy into. When null (default), a new VPC is created.<br/>The existing VPC must already have the required VPC endpoints:<br/>Secrets Manager, SSM, and EC2 (Interface), S3 (Gateway). | <pre>object({<br/>    vpc_id             = string<br/>    private_subnet_ids = list(string)<br/>    public_subnet_ids  = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_nlb_internal"></a> [nlb\_internal](#input\_nlb\_internal) | Whether the NLB is internal. | `bool` | `true` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name prefix for all resources. | `string` | n/a | yes |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Size in GiB of the root EBS volume for Consul nodes. | `number` | `50` | no |
| <a name="input_route53_zone"></a> [route53\_zone](#input\_route53\_zone) | Route 53 hosted zone for the Consul DNS record. | <pre>object({<br/>    zone_id = string<br/>    name    = string<br/>  })</pre> | n/a | yes |
| <a name="input_vault_aws_auth_role"></a> [vault\_aws\_auth\_role](#input\_vault\_aws\_auth\_role) | Name of the Vault AWS auth role bound to the Consul server IAM role. | `string` | `"consul-server"` | no |
| <a name="input_vault_iam_role_name"></a> [vault\_iam\_role\_name](#input\_vault\_iam\_role\_name) | Name of the Vault server IAM role. This module grants the Vault server role `iam:GetRole` on the Consul server IAM role so Vault's AWS auth method can resolve the bound principal during login. | `string` | n/a | yes |
| <a name="input_vault_pki_mount"></a> [vault\_pki\_mount](#input\_vault\_pki\_mount) | Path of the Consul intermediate PKI secrets engine in Vault. | `string` | `"pki_consul"` | no |
| <a name="input_vault_pki_role"></a> [vault\_pki\_role](#input\_vault\_pki\_role) | Name of the Vault PKI role used to issue Consul server certificates. | `string` | `"consul-server"` | no |
| <a name="input_vault_tls_ca_bundle_ssm_parameter_name"></a> [vault\_tls\_ca\_bundle\_ssm\_parameter\_name](#input\_vault\_tls\_ca\_bundle\_ssm\_parameter\_name) | SSM parameter name holding the Vault PKI root+intermediate CA bundle. When null, defaults to /<project\_name>/vault/tls/ca-bundle (the pattern used by terraform-aws-vault-enterprise when the Vault project\_name matches this module's). | `string` | `null` | no |
| <a name="input_vault_url"></a> [vault\_url](#input\_vault\_url) | Base URL of the Vault cluster (scheme and host, no port). For example: "https://vault.example.com". | `string` | n/a | yes |
| <a name="input_vault_version"></a> [vault\_version](#input\_vault\_version) | Vault Enterprise release version (e.g., 1.21.4+ent). | `string` | `"1.21.4+ent"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_private_subnets"></a> [vpc\_private\_subnets](#input\_vpc\_private\_subnets) | Private subnet CIDR blocks. | `list(string)` | <pre>[<br/>  "10.0.1.0/24",<br/>  "10.0.2.0/24",<br/>  "10.0.3.0/24"<br/>]</pre> | no |
| <a name="input_vpc_public_subnets"></a> [vpc\_public\_subnets](#input\_vpc\_public\_subnets) | Public subnet CIDR blocks. | `list(string)` | <pre>[<br/>  "10.0.101.0/24",<br/>  "10.0.102.0/24",<br/>  "10.0.103.0/24"<br/>]</pre> | no |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_autoscaling_group.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_iam_instance_profile.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.consul_agent_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_bootstrap_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_cluster_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_ec2_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_pki_csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_pki_signed_csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_pki_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_tls_ca_bundle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_vault_ca_bundle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.vault_resolve_consul_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.consul_agent_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_bootstrap_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_enterprise_license](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_gossip_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_pki_intermediate_ca_signed_csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.consul_enterprise_license](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.consul_gossip_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.consul_cluster_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.consul_pki_intermediate_ca_csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.consul_pki_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.consul_tls_ca_bundle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_endpoint.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.bastion_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.consul_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.bastion_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_api_external](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_lan_serf_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_lan_serf_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_rpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_wan_serf_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.consul_wan_serf_udp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vpc_endpoints_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.gossip_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.wait_vault_iam_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [vault_aws_auth_backend_role.consul_server](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/aws_auth_backend_role) | resource |
| [vault_mount.pki_consul](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/mount) | resource |
| [vault_policy.consul_server](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/policy) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.consul_agent_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_bootstrap_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_cluster_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_ec2_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_pki_csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_pki_signed_csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_pki_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_tls_ca_bundle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_vault_ca_bundle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vault_resolve_consul_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_bootstrap_token_secret"></a> [bootstrap\_token\_secret](#output\_bootstrap\_token\_secret) | Secrets Manager secret containing the Consul ACL bootstrap token. |
| <a name="output_consul_agent_token_secret_arn"></a> [consul\_agent\_token\_secret\_arn](#output\_consul\_agent\_token\_secret\_arn) | ARN of the Secrets Manager secret containing the Consul server agent token. |
| <a name="output_consul_asg_name"></a> [consul\_asg\_name](#output\_consul\_asg\_name) | Name of the Consul Auto Scaling Group. |
| <a name="output_consul_auto_join_ec2_tag"></a> [consul\_auto\_join\_ec2\_tag](#output\_consul\_auto\_join\_ec2\_tag) | EC2 tag key and value used for Consul auto-join. |
| <a name="output_consul_pki_intermediate_ca_csr_ssm_parameter_name"></a> [consul\_pki\_intermediate\_ca\_csr\_ssm\_parameter\_name](#output\_consul\_pki\_intermediate\_ca\_csr\_ssm\_parameter\_name) | SSM parameter name where the Consul intermediate CA CSR is published. |
| <a name="output_consul_pki_intermediate_ca_signed_csr_secret_arn"></a> [consul\_pki\_intermediate\_ca\_signed\_csr\_secret\_arn](#output\_consul\_pki\_intermediate\_ca\_signed\_csr\_secret\_arn) | Secrets Manager ARN for the signed Consul intermediate CA certificate. |
| <a name="output_consul_snapshots_bucket"></a> [consul\_snapshots\_bucket](#output\_consul\_snapshots\_bucket) | S3 bucket for Consul snapshots. |
| <a name="output_consul_target_group_arn"></a> [consul\_target\_group\_arn](#output\_consul\_target\_group\_arn) | ARN of the Consul NLB target group. |
| <a name="output_consul_tls_ca_bundle_ssm_parameter_name"></a> [consul\_tls\_ca\_bundle\_ssm\_parameter\_name](#output\_consul\_tls\_ca\_bundle\_ssm\_parameter\_name) | SSM parameter name for the Consul PKI TLS CA bundle. |
| <a name="output_consul_url"></a> [consul\_url](#output\_consul\_url) | URL of the Consul cluster. |
| <a name="output_consul_version"></a> [consul\_version](#output\_consul\_version) | Consul Enterprise version deployed. |
| <a name="output_datacenter"></a> [datacenter](#output\_datacenter) | Consul datacenter name. |
| <a name="output_ec2_ami_name"></a> [ec2\_ami\_name](#output\_ec2\_ami\_name) | Name of the AMI used for EC2 instances. |
| <a name="output_gossip_key_secret"></a> [gossip\_key\_secret](#output\_gossip\_key\_secret) | Secrets Manager secret containing the Consul gossip encryption key. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs used by the Consul cluster. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs used by the Consul cluster. |
| <a name="output_security_group"></a> [security\_group](#output\_security\_group) | Consul cluster security group. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID (created or existing). |
<!-- END_TF_DOCS -->
