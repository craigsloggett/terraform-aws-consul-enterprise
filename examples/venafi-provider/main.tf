resource "tls_private_key" "consul_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Replace this `tls_self_signed_cert` placeholder with an actual
# `venafi_certificate` resource. The Venafi provider must be configured
# with `tpp_url` / `zone` (Trust Protection Platform) or `vaas_zone`
# (Venafi as a Service) credentials, and the policy template applied to
# the zone must permit the SANs and key types declared below.
#
# Example real-world replacement (commented out — uncomment, configure
# the provider, and remove the placeholder above before applying):
#
# resource "venafi_certificate" "consul_server" {
#   common_name = "consul.example.com"
#   san_dns     = ["server.dc1.consul", "*.example.com", "localhost"]
#   san_ip      = ["127.0.0.1"]
#   algorithm   = "ECDSA"
#   ecdsa_curve = "P384"
# }
resource "tls_self_signed_cert" "consul_server_placeholder" {
  private_key_pem = tls_private_key.consul_server.private_key_pem

  subject {
    common_name = "venafi-placeholder.invalid"
  }

  validity_period_hours = 1
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "random_id" "gossip_key" {
  byte_length = 32
}

module "consul" {
  source = "../.."

  project_name              = "consul"
  consul_enterprise_license = var.consul_enterprise_license
  ec2_key_pair_name         = "example"

  consul_ca_cert_pem     = tls_self_signed_cert.consul_server_placeholder.cert_pem
  consul_server_cert_pem = tls_self_signed_cert.consul_server_placeholder.cert_pem
  consul_server_key_pem  = tls_private_key.consul_server.private_key_pem
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
