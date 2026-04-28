resource "tls_private_key" "consul_root_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "consul_root_ca" {
  private_key_pem = tls_private_key.consul_root_ca.private_key_pem

  subject {
    common_name = "Example Consul Root CA"
  }

  validity_period_hours = 87600
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "consul_intermediate_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "consul_intermediate_ca" {
  private_key_pem = tls_private_key.consul_intermediate_ca.private_key_pem

  subject {
    common_name = "Example Consul Intermediate CA"
  }
}

resource "tls_locally_signed_cert" "consul_intermediate_ca" {
  cert_request_pem   = tls_cert_request.consul_intermediate_ca.cert_request_pem
  ca_private_key_pem = tls_private_key.consul_root_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.consul_root_ca.cert_pem

  validity_period_hours = 43800
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "consul_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "consul_server" {
  private_key_pem = tls_private_key.consul_server.private_key_pem

  subject {
    common_name = "consul.example.com"
  }

  dns_names = [
    "server.dc1.consul",
    "*.example.com",
    "consul.example.com",
    "localhost",
  ]

  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "consul_server" {
  cert_request_pem   = tls_cert_request.consul_server.cert_request_pem
  ca_private_key_pem = tls_private_key.consul_intermediate_ca.private_key_pem
  ca_cert_pem        = tls_locally_signed_cert.consul_intermediate_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
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

  consul_ca_cert_pem     = "${tls_locally_signed_cert.consul_intermediate_ca.cert_pem}\n${tls_self_signed_cert.consul_root_ca.cert_pem}"
  consul_server_cert_pem = "${tls_locally_signed_cert.consul_server.cert_pem}\n${tls_locally_signed_cert.consul_intermediate_ca.cert_pem}"
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
