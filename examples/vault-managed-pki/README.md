# Vault-managed PKI Consul Enterprise Deployment

This example deploys a Consul Enterprise cluster into a new VPC with an
internal NLB, with TLS and the gossip encryption key managed by an existing
Vault cluster.

The Vault provider creates the prerequisites the module expects to exist ahead
of time: a PKI mount with a root CA and a `consul-server` role, an AWS auth
role bound to the module's IAM role, the gossip encryption key in KV v2, and a
policy tying them together. The module itself never configures Vault; a Vault
Agent on every Consul server authenticates with the AWS auth method and issues
its TLS certificate before Consul starts.

Terraform knows the IAM role ARN before any instance boots, so the AWS auth
role is normally in place first. Even when it is not, the Vault Agent retries
authentication with backoff until the role appears.

> [!WARNING]
> The PKI root CA in this example is created directly on the PKI mount. In an
> established organization the mount would hold an intermediate signed by an
> approved root of trust instead.

## Usage

1. Export a Vault token with permission to create the mounts, roles, and
   policy:

```sh
export VAULT_TOKEN="..."
```

2. Copy the `defaults.auto.tfvars.example` file to `defaults.auto.tfvars` and
   populate:

```hcl
consul_enterprise_license = "LICENSE"
consul_fqdn               = "consul.example.com"
vault_address             = "https://vault.example.com:8200"
vault_ca_chain_pem        = <<-EOT
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
EOT
```

3. Initialize and apply:

```sh
terraform init
terraform apply
```

Terraform configures Vault and deploys the Consul Enterprise cluster. During
cloud-init each node starts a Vault Agent, renders its TLS certificate and the
gossip key, and joins the cluster. The elected bootstrap node then bootstraps
the ACL system and stores the management, server agent, and snapshot agent
tokens in Secrets Manager.

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

### vault.tf

```hcl
# Vault Prerequisites
#
# Everything the module expects to exist in Vault ahead of time: a PKI mount
# and role for the Consul server certificates, an AWS auth role bound to the
# module's IAM role, the gossip encryption key in KV v2, and a policy tying
# them together. The module itself never configures Vault.

## PKI

resource "vault_mount" "pki_consul" {
  path        = "pki_consul"
  type        = "pki"
  description = "PKI for the Consul Enterprise server certificates"

  # 3 years
  max_lease_ttl_seconds = 94608000
}

resource "vault_pki_secret_backend_root_cert" "consul" {
  backend = vault_mount.pki_consul.path
  type    = "internal"

  common_name = "Consul PKI Root CA"
  key_type    = "ec"
  key_bits    = 384

  # 3 years
  ttl = "94608000"
}

resource "vault_pki_secret_backend_role" "consul_server" {
  backend = vault_mount.pki_consul.path
  name    = "consul-server"

  # The server certificate carries the public FQDN, the Consul-internal
  # server.<datacenter>.consul name (required by verify_server_hostname),
  # localhost, and 127.0.0.1.
  allowed_domains    = [var.consul_fqdn, "server.dc1.consul"]
  allow_bare_domains = true
  allow_subdomains   = false
  allow_localhost    = true
  allow_ip_sans      = true

  key_type = "ec"
  key_bits = 384

  # 24 hours
  max_ttl = 86400
}

## AWS Auth

resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "aws"
}

resource "vault_aws_auth_backend_role" "consul_server" {
  backend   = vault_auth_backend.aws.path
  role      = "consul-server"
  auth_type = "iam"

  bound_iam_principal_arns = [module.consul.iam_role_arn]

  # ARN string matching instead of unique ID pinning, so the Vault cluster
  # does not need iam:GetRole on the Consul server role.
  resolve_aws_unique_ids = false

  token_policies = [vault_policy.consul_server.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

resource "vault_policy" "consul_server" {
  name = "consul-server"

  policy = <<-EOT
    path "${vault_mount.pki_consul.path}/issue/consul-server" {
      capabilities = ["create", "update"]
    }

    path "${vault_mount.kv.path}/data/consul/gossip" {
      capabilities = ["read"]
    }
  EOT
}

## Gossip Encryption Key

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  description = "KV v2 secrets for the Consul Enterprise servers"

  options = {
    version = "2"
  }
}

resource "random_bytes" "gossip_key" {
  length = 32
}

resource "vault_kv_secret_v2" "consul_gossip" {
  mount = vault_mount.kv.path
  name  = "consul/gossip"

  data_json = jsonencode({
    key = random_bytes.gossip_key.base64
  })
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.49.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.9.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | 5.9.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_vault"></a> [vault](#provider\_vault) | 5.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_consul_enterprise_license"></a> [consul\_enterprise\_license](#input\_consul\_enterprise\_license) | Consul Enterprise license string. | `string` | n/a | yes |
| <a name="input_consul_fqdn"></a> [consul\_fqdn](#input\_consul\_fqdn) | Fully qualified domain name in presentation form for the Consul Enterprise cluster. | `string` | n/a | yes |
| <a name="input_vault_address"></a> [vault\_address](#input\_vault\_address) | HTTPS URL of the existing Vault cluster that manages PKI for the Consul servers. | `string` | n/a | yes |
| <a name="input_vault_ca_chain_pem"></a> [vault\_ca\_chain\_pem](#input\_vault\_ca\_chain\_pem) | PEM-encoded CA chain the Consul servers use to verify the Vault cluster's TLS certificate. | `string` | n/a | yes |

## Resources

| Name | Type |
| ---- | ---- |
| [random_bytes.gossip_key](https://registry.terraform.io/providers/hashicorp/random/3.9.0/docs/resources/bytes) | resource |
| [vault_auth_backend.aws](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/auth_backend) | resource |
| [vault_aws_auth_backend_role.consul_server](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/aws_auth_backend_role) | resource |
| [vault_kv_secret_v2.consul_gossip](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/kv_secret_v2) | resource |
| [vault_mount.kv](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/mount) | resource |
| [vault_mount.pki_consul](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/mount) | resource |
| [vault_pki_secret_backend_role.consul_server](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/pki_secret_backend_role) | resource |
| [vault_pki_secret_backend_root_cert.consul](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/pki_secret_backend_root_cert) | resource |
| [vault_policy.consul_server](https://registry.terraform.io/providers/hashicorp/vault/5.9.0/docs/resources/policy) | resource |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_consul_url"></a> [consul\_url](#output\_consul\_url) | URL of the Consul cluster. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the Consul server IAM role bound to the Vault AWS auth role. |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | AWS-assigned DNS name of the Consul NLB. |
| <a name="output_nlb_zone_id"></a> [nlb\_zone\_id](#output\_nlb\_zone\_id) | Hosted zone ID of the Consul NLB. |
<!-- END_TF_DOCS -->
