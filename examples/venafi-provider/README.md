# Venafi Provider Signing Example

**Stub — not wired up end-to-end.** This example shows where the
[Venafi](https://registry.terraform.io/providers/Venafi/venafi/latest/docs)
provider would slot in to issue the Consul server certificate.

## How to use

1. Configure the `venafi` provider in `versions.tf` and add a `provider
   "venafi"` block in `main.tf` with credentials for either Trust
   Protection Platform (`tpp_url` + `access_token`) or Venafi as a
   Service (`api_key` + `vaas_zone`).
2. Replace the `tls_self_signed_cert.consul_server_placeholder`
   resource in `main.tf` with a `venafi_certificate` resource. Wire its
   `certificate` output into `consul_server_cert_pem` and the matching
   `chain` (or trust bundle from your Venafi policy) into
   `consul_ca_cert_pem`.
3. Confirm the Venafi policy template applied to the chosen zone permits
   the SANs (`server.<dc>.consul`, the FQDN, `localhost`) and key
   algorithm (ECDSA P-384) declared in the placeholder.

The placeholder allows `terraform validate` to pass without Venafi
credentials present, but the resulting certificate is not usable for a
real cluster.
