#!/bin/sh
# Usage: CONSUL_HTTP_TOKEN=$(jq -r '.SecretID' consul-bootstrap.json) ./smoke-test.sh

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  bastion_ip=$(terraform output -raw bastion_public_ip)
  consul_ip=$(terraform output -json consul_private_ips | jq -r '.[0]')
  consul_ca_cert=$(terraform output -raw consul_ca_cert)
  ami_name=$(terraform output -raw ec2_ami_name)

  case "${ami_name}" in
    *ubuntu*) ssh_user="ubuntu" ;;
    *debian*) ssh_user="admin" ;;
    *)
      log "ERROR: Unsupported AMI:" "${ami_name}"
      exit 1
      ;;
  esac

  log "  Bastion IP:" "${bastion_ip}"
  log "  Consul node:" "${consul_ip}"
  log "  SSH user:" "${ssh_user}"
}

setup_tunnel() {
  log "Opening SSH tunnel to ${consul_ip}:8501."

  ca_cert_file=$(mktemp)
  ssh_socket=$(mktemp -u)
  printf '%s\n' "${consul_ca_cert}" >"${ca_cert_file}"

  # shellcheck disable=SC2086
  ssh ${ssh_opts} -f -N -M -S "${ssh_socket}" \
    -L 8501:"${consul_ip}":8501 "${ssh_user}@${bastion_ip}"

  export CONSUL_HTTP_ADDR="https://127.0.0.1:8501"
  export CONSUL_CACERT="${ca_cert_file}"
}

cleanup() {
  rm -f "${ca_cert_file}"
  ssh -S "${ssh_socket}" -O exit x 2>/dev/null
}

wait_for_consul() {
  log "Waiting for Consul to be reachable."

  attempts=0
  max_attempts=30
  while ! curl -sf --cacert "${ca_cert_file}" \
    "${CONSUL_HTTP_ADDR}/v1/status/leader" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "${attempts}" -ge "${max_attempts}" ]; then
      log "ERROR: Consul not reachable after ${max_attempts} attempts."
      exit 1
    fi
    sleep 2
  done

  log "Consul is reachable."
}

test_cluster_health() {
  log "Checking cluster health."
  consul members
  consul operator raft list-peers
}

test_kv_store() {
  log "Testing KV store."
  consul kv put smoke-test/message "smoke test"
  consul kv get smoke-test/message
  consul kv delete smoke-test/message
  log "  KV smoke test passed."
}

test_license() {
  log "Checking license status."
  consul license get
}

main() {
  set -ef
  : "${CONSUL_HTTP_TOKEN:?Set CONSUL_HTTP_TOKEN before running this script.}"
  export CONSUL_HTTP_TOKEN

  ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

  # Colors are automatically disabled if output is not a terminal.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  read_terraform_outputs
  trap cleanup EXIT
  setup_tunnel
  wait_for_consul
  test_cluster_health
  test_kv_store
  test_license

  log "All smoke tests passed."
}

main "$@"
