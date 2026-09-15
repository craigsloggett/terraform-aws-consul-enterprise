#!/bin/sh
# initialize-consul-acl.sh
#
# Bootstraps the Consul ACL system on the elected bootstrap node. Publishes the
# API CA chain to SSM, runs consul acl bootstrap, publishes the management token
# to Secrets Manager, creates the server agent and snapshot agent policies and
# tokens, and marks cluster_state=Ready in SSM. Followers no-op. Runs after the
# local consul.service is up and listening.

set -euf

# shellcheck source=bootstrap.env.tftpl
. /var/lib/cloud/scripts/bootstrap.env
# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

readonly CONSUL_POLICY_DIR="/etc/consul.d/policies"
readonly CONSUL_TLS_CA_FILE="/opt/consul/tls/ca.pem"

consul_cluster_ready() (
  consul_cluster_state="$(
    fetch_parameter "${BOOTSTRAP_CONSUL_CLUSTER_STATE_SSM_PARAMETER_NAME}" 2>/dev/null
  )" || consul_cluster_state=""

  [ "${consul_cluster_state}" = "Ready" ]
)

raft_leader_elected() (
  raft_leader="$(
    curl --silent --cacert "${CONSUL_TLS_CA_FILE}" \
      "https://127.0.0.1:8501/v1/status/leader" 2>/dev/null
  )" ||
    return 1

  [ -n "${raft_leader}" ] &&
    [ "${raft_leader}" != '""' ]
)

await_raft_leader() (
  log_info "Waiting for a Raft leader to be elected"

  timeout_seconds=1200
  retry_for "${timeout_seconds}" raft_leader_elected ||
    {
      log_error "No Raft leader elected after ${timeout_seconds}s"
      return 1
    }
)

bootstrap_acl_system() (
  log_info "Bootstrapping the Consul ACL system"

  acl_bootstrap_exit_code=0
  acl_bootstrap_output="$(consul acl bootstrap -format=json 2>&1)" ||
    acl_bootstrap_exit_code="$?"

  if [ "${acl_bootstrap_exit_code}" -ne 0 ]; then
    case "${acl_bootstrap_output}" in
      *"ACL bootstrap no longer allowed"*)
        log_warn "ACL system already bootstrapped, using the stored management token"
        return 0
        ;;
      *)
        log_error "consul acl bootstrap failed: ${acl_bootstrap_output}"
        return 1
        ;;
    esac
  fi

  management_token="$(printf '%s' "${acl_bootstrap_output}" | jq -r '.SecretID')"

  log_info "Storing the ACL management token in Secrets Manager"
  put_secret "${ACL_MANAGEMENT_TOKEN_SECRET_ARN}" "${management_token}"
)

create_acl_policies_and_tokens() (
  CONSUL_HTTP_TOKEN="$(fetch_secret "${ACL_MANAGEMENT_TOKEN_SECRET_ARN}")"
  export CONSUL_HTTP_TOKEN

  log_info "Creating the consul-agent ACL policy and token"
  consul acl policy create \
    -name consul-agent \
    -description "Consul server agent policy" \
    -rules "@${CONSUL_POLICY_DIR}/consul-agent.hcl" \
    >/dev/null

  agent_token="$(
    consul acl token create \
      -policy-name consul-agent \
      -description "Consul server agent token" \
      -format=json | jq -r '.SecretID'
  )"

  log_info "Storing the ACL server agent token in Secrets Manager"
  put_secret "${ACL_AGENT_TOKEN_SECRET_ARN}" "${agent_token}"

  log_info "Creating the consul-snapshot-agent ACL policy and token"
  consul acl policy create \
    -name consul-snapshot-agent \
    -description "Consul snapshot agent policy" \
    -rules "@${CONSUL_POLICY_DIR}/consul-snapshot-agent.hcl" \
    >/dev/null

  snapshot_agent_token="$(
    consul acl token create \
      -policy-name consul-snapshot-agent \
      -description "Consul snapshot agent token" \
      -format=json | jq -r '.SecretID'
  )"

  log_info "Storing the ACL snapshot agent token in Secrets Manager"
  put_secret "${ACL_SNAPSHOT_AGENT_TOKEN_SECRET_ARN}" "${snapshot_agent_token}"
)

publish_cluster_ready() (
  log_info "Writing cluster state: Ready"

  put_parameter "${BOOTSTRAP_CONSUL_CLUSTER_STATE_SSM_PARAMETER_NAME}" "Ready"

  log_info "Cluster initialization complete"
)

# publish_ca_chain stores the Vault Agent-issued CA chain in SSM so callers
# outside the VPC (the deploy repo's node-replacement test) can trust the Consul
# API. Intelligent-Tiering absorbs a chain larger than the Standard 4 KB limit.
publish_ca_chain() (
  log_info "Publishing the Consul API CA chain to SSM"

  aws ssm put-parameter \
    --name "${BOOTSTRAP_CONSUL_PKI_CA_CHAIN_SSM_PARAMETER_NAME}" \
    --value "file://${CONSUL_TLS_CA_FILE}" \
    --type String \
    --tier Intelligent-Tiering \
    --overwrite \
    >/dev/null
)

main() {
  bootstrap_instance_id="$(fetch_parameter "${BOOTSTRAP_INSTANCE_ID_SSM_PARAMETER_NAME}")"

  if [ "${INSTANCE_ID}" != "${bootstrap_instance_id}" ]; then
    return 0
  fi

  publish_ca_chain

  if consul_cluster_ready; then
    log_info "Consul ACL system already bootstrapped, skipping"
    return 0
  fi

  export CONSUL_HTTP_ADDR="https://127.0.0.1:8501"
  export CONSUL_CACERT="${CONSUL_TLS_CA_FILE}"

  await_raft_leader
  bootstrap_acl_system
  create_acl_policies_and_tokens
  publish_cluster_ready
}

main "$@"
