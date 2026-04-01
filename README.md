# HashiCorp Consul Enterprise Terraform Module
A Terraform module for deploying HashiCorp Consul Enterprise on AWS.

<!-- BEGIN_TF_DOCS -->
## Usage

### main.tf
```hcl
data "aws_route53_zone" "selected" {
  name = var.route53_zone_name
}

data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-13-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "consul" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/craigsloggett/terraform-aws-consul-enterprise"

  project_name      = "consul-enterprise"
  route53_zone      = data.aws_route53_zone.selected
  consul_license    = var.consul_license
  ec2_key_pair_name = var.ec2_key_pair_name
  ec2_ami           = data.aws_ami.debian
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bastion_allowed_cidrs"></a> [bastion\_allowed\_cidrs](#input\_bastion\_allowed\_cidrs) | CIDR blocks allowed to SSH to the bastion host. Defaults to 0.0.0.0/0 for convenience; restrict to known ranges in any production deployment. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_bastion_instance_type"></a> [bastion\_instance\_type](#input\_bastion\_instance\_type) | EC2 instance type for the bastion host. | `string` | `"t3.micro"` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_consul_api_allowed_cidrs"></a> [consul\_api\_allowed\_cidrs](#input\_consul\_api\_allowed\_cidrs) | CIDR blocks allowed to reach the Consul API (port 8501) from outside the VPC. Only effective when nlb\_internal is false. | `list(string)` | `[]` | no |
| <a name="input_consul_datacenter"></a> [consul\_datacenter](#input\_consul\_datacenter) | Consul datacenter name. | `string` | `"dc1"` | no |
| <a name="input_consul_ebs_volume_size"></a> [consul\_ebs\_volume\_size](#input\_consul\_ebs\_volume\_size) | Size in GiB of the EBS volume for Consul Raft storage. | `number` | `100` | no |
| <a name="input_consul_instance_type"></a> [consul\_instance\_type](#input\_consul\_instance\_type) | EC2 instance type for Consul nodes. | `string` | `"m5.large"` | no |
| <a name="input_consul_license"></a> [consul\_license](#input\_consul\_license) | Consul Enterprise license string. | `string` | n/a | yes |
| <a name="input_consul_package_version"></a> [consul\_package\_version](#input\_consul\_package\_version) | Consul Enterprise apt package version to install (e.g., 1.22.6+ent-1). | `string` | `"1.22.6+ent-1"` | no |
| <a name="input_consul_snapshot_interval"></a> [consul\_snapshot\_interval](#input\_consul\_snapshot\_interval) | Interval between automated Raft snapshots (e.g., 1h, 30m, 24h). | `string` | `"1h"` | no |
| <a name="input_consul_snapshot_retain"></a> [consul\_snapshot\_retain](#input\_consul\_snapshot\_retain) | Number of automated Raft snapshots to retain in S3. | `number` | `72` | no |
| <a name="input_consul_subdomain"></a> [consul\_subdomain](#input\_consul\_subdomain) | Subdomain for the Consul DNS record. | `string` | `"consul"` | no |
| <a name="input_ec2_ami"></a> [ec2\_ami](#input\_ec2\_ami) | AMI to use for EC2 instances. Must be Ubuntu or Debian-based. | <pre>object({<br/>    id   = string<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_ec2_key_pair_name"></a> [ec2\_key\_pair\_name](#input\_ec2\_key\_pair\_name) | Name of an existing EC2 key pair for SSH access. | `string` | n/a | yes |
| <a name="input_existing_vpc"></a> [existing\_vpc](#input\_existing\_vpc) | Existing VPC to deploy into. When null (default), a new VPC is created.<br/>The existing VPC must already have the required VPC endpoints:<br/>Secrets Manager and EC2 (Interface), S3 (Gateway). | <pre>object({<br/>    vpc_id             = string<br/>    private_subnet_ids = list(string)<br/>    public_subnet_ids  = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_nlb_internal"></a> [nlb\_internal](#input\_nlb\_internal) | Whether the NLB is internal. | `bool` | `true` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name prefix for all resources. | `string` | n/a | yes |
| <a name="input_route53_zone"></a> [route53\_zone](#input\_route53\_zone) | Route 53 hosted zone for the Consul DNS record. | <pre>object({<br/>    zone_id = string<br/>    name    = string<br/>  })</pre> | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_private_subnets"></a> [vpc\_private\_subnets](#input\_vpc\_private\_subnets) | Private subnet CIDR blocks. | `list(string)` | <pre>[<br/>  "10.0.1.0/24",<br/>  "10.0.2.0/24",<br/>  "10.0.3.0/24"<br/>]</pre> | no |
| <a name="input_vpc_public_subnets"></a> [vpc\_public\_subnets](#input\_vpc\_public\_subnets) | Public subnet CIDR blocks. | `list(string)` | <pre>[<br/>  "10.0.101.0/24",<br/>  "10.0.102.0/24",<br/>  "10.0.103.0/24"<br/>]</pre> | no |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_ebs_volume.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_iam_instance_profile.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.consul_ec2_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.consul_secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_lb.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.consul_ca_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_gossip_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_license](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_nomad_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_server_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.consul_server_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.consul_ca_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.consul_gossip_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.consul_license](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.consul_server_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.consul_server_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_volume_attachment.consul](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [aws_vpc_endpoint.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
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
| [tls_cert_request.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.consul_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_ec2_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.consul_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_ca_cert_secret"></a> [ca\_cert\_secret](#output\_ca\_cert\_secret) | Secrets Manager secret containing the Consul CA certificate. |
| <a name="output_cluster_tag"></a> [cluster\_tag](#output\_cluster\_tag) | EC2 tag key and value used for Consul auto-join. |
| <a name="output_consul_ca_cert"></a> [consul\_ca\_cert](#output\_consul\_ca\_cert) | CA certificate for trusting the Consul TLS chain. |
| <a name="output_consul_private_ips"></a> [consul\_private\_ips](#output\_consul\_private\_ips) | Private IPs of the Consul nodes. |
| <a name="output_consul_snapshot_bucket"></a> [consul\_snapshot\_bucket](#output\_consul\_snapshot\_bucket) | S3 bucket for Consul snapshots. |
| <a name="output_consul_target_group_arn"></a> [consul\_target\_group\_arn](#output\_consul\_target\_group\_arn) | ARN of the Consul NLB target group. |
| <a name="output_consul_url"></a> [consul\_url](#output\_consul\_url) | URL of the Consul cluster. |
| <a name="output_datacenter"></a> [datacenter](#output\_datacenter) | Consul datacenter name. |
| <a name="output_ec2_ami_name"></a> [ec2\_ami\_name](#output\_ec2\_ami\_name) | Name of the AMI used for EC2 instances. |
| <a name="output_gossip_key_secret"></a> [gossip\_key\_secret](#output\_gossip\_key\_secret) | Secrets Manager secret containing the Consul gossip encryption key. |
| <a name="output_nomad_token_secret"></a> [nomad\_token\_secret](#output\_nomad\_token\_secret) | Secrets Manager secret containing the Consul ACL token for Nomad. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs used by the Consul cluster. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs used by the Consul cluster. |
| <a name="output_security_group"></a> [security\_group](#output\_security\_group) | Consul cluster security group. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID (created or existing). |
<!-- END_TF_DOCS -->
