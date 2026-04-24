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
