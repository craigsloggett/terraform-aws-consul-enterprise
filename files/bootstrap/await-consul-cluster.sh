#!/bin/sh
# await-consul-cluster.sh
#
# Waits for the Consul cluster to be initialized (cluster_state=Ready in SSM)
# and for the local node to see a Raft leader. Runs on every node after
# initialize-consul-acl.sh. The bootstrap node passes through quickly since
# it just published Ready and already waited on leader election.

set -euf

# shellcheck source=bootstrap.env.tftpl
. /var/lib/cloud/scripts/bootstrap.env
# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

readonly CONSUL_TLS_CA_FILE="/opt/consul/tls/ca.pem"

consul_cluster_ready() (
  consul_cluster_state="$(fetch_parameter "${BOOTSTRAP_CONSUL_CLUSTER_STATE_SSM_PARAMETER_NAME}")" ||
    return 1

  [ "${consul_cluster_state}" = "Ready" ]
)

await_consul_cluster() (
  log_info "Waiting for the Consul cluster to be initialized"

  timeout_seconds=1200
  retry_for "${timeout_seconds}" consul_cluster_ready ||
    {
      log_error "Consul cluster did not become ready after ${timeout_seconds}s"
      return 1
    }
)

raft_leader_known() (
  raft_leader="$(
    curl --silent --cacert "${CONSUL_TLS_CA_FILE}" \
      "https://127.0.0.1:8501/v1/status/leader" 2>/dev/null
  )" ||
    return 1

  [ -n "${raft_leader}" ] &&
    [ "${raft_leader}" != '""' ]
)

await_raft_leader() (
  log_info "Waiting for the local node to see a Raft leader"

  timeout_seconds=1200
  retry_for "${timeout_seconds}" raft_leader_known ||
    {
      log_error "No Raft leader seen after ${timeout_seconds}s"
      return 1
    }
)

main() {
  await_consul_cluster
  await_raft_leader
}

main "$@"
