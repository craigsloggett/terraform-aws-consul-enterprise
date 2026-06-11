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
