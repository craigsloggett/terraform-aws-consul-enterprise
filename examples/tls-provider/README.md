# TLS Provider Signing Example

Generates a three-tier PKI hierarchy entirely with the
[`hashicorp/tls`](https://registry.terraform.io/providers/hashicorp/tls/latest/docs)
provider and feeds the result into the Consul cluster module:

1. Self-signed root CA.
2. Intermediate CA, with its CSR signed by the root.
3. Consul server certificate, with its CSR signed by the intermediate.

The module receives the intermediate plus root concatenated as the trust
bundle (`consul_ca_cert_pem`) and the server certificate plus intermediate
as the cert chain to present (`consul_server_cert_pem`).

This is the lab default. For enterprise deployments, swap the
`tls_locally_signed_cert` resources for a dedicated CA signing pattern —
see the `venafi-provider` and `operator-out-of-band` examples.
