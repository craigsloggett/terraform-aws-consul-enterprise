# Operator Out-of-Band Signing Example

For environments where the root CA is offline or otherwise unavailable
to Terraform — for example, an HSM-backed enterprise CA or an air-gapped
signing ceremony — the operator generates the Consul server certificate
out of band and supplies the PEMs as variables.

## How to use

1. Generate a Consul server keypair on the operator workstation
   (`openssl req -newkey ec:<curve.pem> -nodes -keyout server.key -out
   server.csr` or equivalent), with a CSR that includes the SANs the
   cluster expects: `server.<dc>.consul`, the cluster FQDN,
   `localhost`, `127.0.0.1`.
2. Sign the CSR with the operator-controlled CA, producing
   `server.crt`. Concatenate any intermediates plus the root CA
   certificate into a trust bundle.
3. Pass the PEM contents into Terraform as variables
   (`consul_ca_cert_pem`, `consul_server_cert_pem`,
   `consul_server_key_pem`) — typically through environment variables
   (`TF_VAR_consul_server_key_pem=$(cat server.key)`) or a
   short-lived `*.tfvars` file kept outside version control.
4. Apply.

Rotation is handled out of band by re-running the same workflow with a
new keypair and certificate, then `terraform apply` to roll the new
materials through Secrets Manager. ASG instance refresh picks up the
change.
