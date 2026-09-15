#!/bin/sh
# start-consul.sh
#
# Starts the local Consul systemd unit and waits for the local HTTPS API to
# begin responding. Runs on every node after the Consul binary, license, TLS
# materials, gossip key, and configuration files are in place.

set -euf

# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

readonly CONSUL_TLS_CA_FILE="/opt/consul/tls/ca.pem"

start_consul() (
  log_info "Starting consul.service"

  systemctl daemon-reload
  systemctl enable --now consul
)

consul_api_ready() (
  status="$(
    curl --silent --cacert "${CONSUL_TLS_CA_FILE}" \
      --output /dev/null --write-out '%{http_code}' \
      "https://127.0.0.1:8501/v1/status/leader" 2>/dev/null
  )" ||
    return 1

  [ "${status}" != "000" ]
)

await_consul_api() (
  log_info "Waiting for the Consul API to be ready"

  timeout_seconds=1200
  retry_for "${timeout_seconds}" consul_api_ready ||
    {
      log_error "Consul API did not respond after ${timeout_seconds}s"
      return 1
    }
)

main() {
  start_consul
  await_consul_api
}

main "$@"
