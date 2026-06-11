#!/bin/sh
# install-consul-enterprise-license.sh
#
# Fetches the Consul Enterprise license from Secrets Manager and writes it
# to /opt/consul/consul.hclic. Runs on every node before consul.service starts.

set -euf

# shellcheck source=bootstrap.env.tftpl
. /var/lib/cloud/scripts/bootstrap.env
# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

readonly CONSUL_HOME_DIR="/opt/consul"

TMPDIR_SESSION="$(mktemp -d)"
readonly TMPDIR_SESSION
trap 'rm -rf "${TMPDIR_SESSION}"' EXIT INT TERM HUP

install_consul_enterprise_license() (
  log_info "Installing the Consul Enterprise license"

  tmp_consul_enterprise_license_file="${TMPDIR_SESSION}/consul.hclic"
  printf '%s' "$(fetch_secret "${LICENSE_SECRET_ARN}")" >"${tmp_consul_enterprise_license_file}"

  install -o consul -g consul -m 0640 "${tmp_consul_enterprise_license_file}" "${CONSUL_HOME_DIR}/consul.hclic"
)

main() {
  install_consul_enterprise_license
}

main "$@"
