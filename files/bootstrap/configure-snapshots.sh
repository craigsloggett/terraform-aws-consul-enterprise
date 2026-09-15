#!/bin/sh
# configure-snapshots.sh
#
# Fetches the snapshot agent ACL token, writes the snapshot agent environment
# file, and starts the Consul snapshot agent. Runs on every node; the
# snapshot agents elect a single active instance among themselves using a
# Consul lock.

set -euf

# shellcheck source=bootstrap.env.tftpl
. /var/lib/cloud/scripts/bootstrap.env
# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

readonly SNAPSHOT_AGENT_ENV_FILE="/etc/consul-snapshot.d/snapshot-agent.env"

TMPDIR_SESSION="$(mktemp -d)"
readonly TMPDIR_SESSION
trap 'rm -rf "${TMPDIR_SESSION}"' EXIT INT TERM HUP

write_snapshot_agent_environment() (
  log_info "Writing the snapshot agent environment file"

  snapshot_agent_token="$(fetch_secret "${ACL_SNAPSHOT_AGENT_TOKEN_SECRET_ARN}")"

  tmp_snapshot_agent_env_file="${TMPDIR_SESSION}/snapshot-agent.env"
  printf 'CONSUL_HTTP_TOKEN=%s\n' "${snapshot_agent_token}" >"${tmp_snapshot_agent_env_file}"

  install -o root -g root -m 0600 "${tmp_snapshot_agent_env_file}" "${SNAPSHOT_AGENT_ENV_FILE}"
)

start_snapshot_agent() (
  log_info "Starting consul-snapshot-agent.service"

  systemctl enable --now consul-snapshot-agent
)

main() {
  write_snapshot_agent_environment
  start_snapshot_agent
}

main "$@"
