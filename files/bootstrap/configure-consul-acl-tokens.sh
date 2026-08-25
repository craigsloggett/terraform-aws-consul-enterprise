#!/bin/sh
# configure-consul-acl-tokens.sh
#
# Fetches the shared server agent token from Secrets Manager and assigns it
# to the local agent. The assignment is persisted by Consul's token
# persistence, so it survives restarts. Runs on every node after the cluster
# is initialized.

set -euf

# shellcheck source=bootstrap.env.tftpl
. /var/lib/cloud/scripts/bootstrap.env
# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

set_agent_token() (
  log_info "Setting the Consul agent token"

  agent_token="$(fetch_secret "${ACL_AGENT_TOKEN_SECRET_ARN}")"

  consul acl set-agent-token agent "${agent_token}"
)

main() {
  export CONSUL_HTTP_ADDR="https://127.0.0.1:8501"
  export CONSUL_CACERT="/opt/consul/tls/ca.pem"

  CONSUL_HTTP_TOKEN="$(fetch_secret "${ACL_MANAGEMENT_TOKEN_SECRET_ARN}")"
  export CONSUL_HTTP_TOKEN

  set_agent_token
}

main "$@"
