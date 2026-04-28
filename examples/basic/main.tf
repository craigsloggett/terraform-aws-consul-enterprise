resource "random_id" "gossip_key" {
  byte_length = 32
}

module "consul" {
  source = "../.."

  project_name              = "consul"
  consul_enterprise_license = var.consul_enterprise_license
  ec2_key_pair_name         = "example"

  consul_gossip_key = random_id.gossip_key.b64_std

  vault_address       = "https://vault.example.com:8200"
  vault_ca_cert_pem   = var.vault_ca_cert_pem
  vault_aws_auth_role = "consul-server"
  vault_agent_version = "1.18.4"

  ec2_ami = {
    id   = "ami-0example"
    name = "ubuntu-example"
  }

  route53_zone = {
    zone_id = "Z0000000000000"
    name    = "example.com"
  }
}
