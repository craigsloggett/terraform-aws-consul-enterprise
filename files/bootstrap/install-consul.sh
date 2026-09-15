#!/bin/sh
# install-consul.sh
#
# Downloads, GPG-verifies, SHA256-verifies, and installs the Consul Enterprise
# binary at /usr/local/bin/consul. Runs on every node before the cluster
# bootstrap.

set -euf

# shellcheck source=bootstrap.env.tftpl
. /var/lib/cloud/scripts/bootstrap.env
# shellcheck source=SCRIPTDIR/common-functions.sh
. /var/lib/cloud/scripts/common-functions.sh

TMPDIR_SESSION="$(mktemp -d)"
readonly TMPDIR_SESSION
trap 'rm -rf "${TMPDIR_SESSION}"' EXIT INT TERM HUP

detect_system_architecture() (
  machine="$(uname -m)"
  case "${machine}" in
    x86_64) printf 'amd64' ;;
    aarch64) printf 'arm64' ;;
    *)
      log_error "Unsupported architecture: ${machine}"
      return 1
      ;;
  esac
)

fetch_consul_release_and_signing_key() (
  consul_release_filename="$1"
  consul_release_sha256sums_filename="$2"

  log_info "Downloading Consul Enterprise ${CONSUL_VERSION}"
  curl --fail --silent --show-error --location \
    --output "${TMPDIR_SESSION}/${consul_release_filename}" \
    "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${consul_release_filename}"

  log_info "Downloading Consul Enterprise ${CONSUL_VERSION} SHA256SUMS file"
  curl --fail --silent --show-error --location \
    --output "${TMPDIR_SESSION}/${consul_release_sha256sums_filename}" \
    "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${consul_release_sha256sums_filename}"

  log_info "Downloading Consul Enterprise ${CONSUL_VERSION} SHA256SUMS signature file"
  curl --fail --silent --show-error --location \
    --output "${TMPDIR_SESSION}/${consul_release_sha256sums_filename}.sig" \
    "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${consul_release_sha256sums_filename}.sig"

  log_info "Downloading HashiCorp signing key"
  curl --fail --silent --show-error --location \
    --output "${TMPDIR_SESSION}/hashicorp.asc" \
    https://www.hashicorp.com/.well-known/pgp-key.txt
)

verify_consul_release() (
  consul_release_filename="$1"
  consul_release_sha256sums_filename="$2"

  export GNUPGHOME="${TMPDIR_SESSION}/.gnupg"
  mkdir -p "${GNUPGHOME}"
  chmod 0700 "${GNUPGHOME}"

  log_info "Trusting HashiCorp signing key"
  gpg --quiet --import "${TMPDIR_SESSION}/hashicorp.asc"
  printf '%s\n' "C874011F0AB405110D02105534365D9472D7468F:6:" | gpg --quiet --import-ownertrust

  log_info "Verifying ${consul_release_sha256sums_filename} signature"
  gpg --quiet --verify \
    "${TMPDIR_SESSION}/${consul_release_sha256sums_filename}.sig" \
    "${TMPDIR_SESSION}/${consul_release_sha256sums_filename}"

  log_info "Verifying ${consul_release_filename} checksum"
  cd "${TMPDIR_SESSION}" &&
    sha256sum --check --ignore-missing "${consul_release_sha256sums_filename}"
)

install_consul() (
  consul_release_filename="$1"

  log_info "Installing Consul Enterprise ${CONSUL_VERSION}"
  unzip -o -q "${TMPDIR_SESSION}/${consul_release_filename}" -d "${TMPDIR_SESSION}"
  install -o root -g root -m 0755 "${TMPDIR_SESSION}/consul" /usr/local/bin/consul
)

main() {
  consul_release_filename="consul_${CONSUL_VERSION}_linux_$(detect_system_architecture).zip"
  consul_release_sha256sums_filename="consul_${CONSUL_VERSION}_SHA256SUMS"

  fetch_consul_release_and_signing_key "${consul_release_filename}" "${consul_release_sha256sums_filename}"
  verify_consul_release "${consul_release_filename}" "${consul_release_sha256sums_filename}"
  install_consul "${consul_release_filename}"
}

main "$@"
