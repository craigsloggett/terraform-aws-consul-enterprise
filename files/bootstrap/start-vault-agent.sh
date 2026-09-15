#!/bin/sh
# start-vault-agent.sh
#
# Starts the Vault Agent and waits for it to render the Consul server TLS
# materials and the gossip encryption key from the external Vault cluster.
# Runs on every node before consul.service starts. The agent authenticates
# with the AWS auth method and retries indefinitely, so this also absorbs
# the window where the Vault AWS auth role is still being configured.

set -euf

# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

readonly CONSUL_TLS_DIR="/opt/consul/tls"
readonly CONSUL_GOSSIP_FILE="/etc/consul.d/gossip.hcl"

start_vault_agent() (
  log_info "Starting vault-agent.service"

  systemctl daemon-reload
  systemctl enable --now vault-agent
)

vault_agent_files_rendered() (
  for rendered_file in \
    "${CONSUL_TLS_DIR}/server.crt" \
    "${CONSUL_TLS_DIR}/server.key" \
    "${CONSUL_TLS_DIR}/ca.pem" \
    "${CONSUL_GOSSIP_FILE}"; do
    [ -s "${rendered_file}" ] ||
      return 1
  done

  return 0
)

await_vault_agent_files() (
  log_info "Waiting for the Vault Agent to render the TLS materials and gossip key"

  timeout_seconds=1200
  retry_for "${timeout_seconds}" vault_agent_files_rendered ||
    {
      log_error "Vault Agent did not render all files after ${timeout_seconds}s"
      return 1
    }
)

main() {
  start_vault_agent
  await_vault_agent_files
}

main "$@"
