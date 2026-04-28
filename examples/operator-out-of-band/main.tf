resource "random_id" "gossip_key" {
  byte_length = 32
}

module "consul" {
  source = "../.."

  project_name              = "consul"
  consul_enterprise_license = var.consul_enterprise_license
  ec2_key_pair_name         = "example"

  consul_ca_cert_pem     = var.consul_ca_cert_pem
  consul_server_cert_pem = var.consul_server_cert_pem
  consul_server_key_pem  = var.consul_server_key_pem
  consul_gossip_key      = random_id.gossip_key.b64_std

  ec2_ami = {
    id   = "ami-0example"
    name = "ubuntu-example"
  }

  route53_zone = {
    zone_id = "Z0000000000000"
    name    = "example.com"
  }
}
