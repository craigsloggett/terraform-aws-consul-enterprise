#!/bin/sh
# Usage: ./initialize-cluster.sh

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  bastion_ip=$(terraform output -raw bastion_public_ip)
  consul_ip=$(terraform output -json consul_private_ips | jq -r '.[0]')
  consul_ips=$(terraform output -json consul_private_ips | jq -r '.[]')
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

bootstrap_acl() {
  if [ -f consul-bootstrap.json ]; then
    log "Bootstrap token file already exists."
    export CONSUL_HTTP_TOKEN
    CONSUL_HTTP_TOKEN=$(jq -r '.SecretID' consul-bootstrap.json)
    return
  fi

  log "Bootstrapping the ACL system."

  if ! consul acl bootstrap -format=json >consul-bootstrap.json 2>/dev/null; then
    log "ERROR: ACL bootstrap failed. System may already be bootstrapped."
    log "       Place the bootstrap token in consul-bootstrap.json to continue."
    exit 1
  fi

  cat consul-bootstrap.json

  export CONSUL_HTTP_TOKEN
  CONSUL_HTTP_TOKEN=$(jq -r '.SecretID' consul-bootstrap.json)

  log "ACL system bootstrapped."
  log "IMPORTANT: The bootstrap token has been saved to consul-bootstrap.json." "" "!!"
  log "           Store this file securely and delete it from disk." "" "  "
}

configure_snapshots() {
  log "Configuring the snapshot agent."

  # Create a policy for the snapshot agent.
  consul acl policy create \
    -name="snapshot-agent" \
    -description="Policy for the Consul snapshot agent" \
    -rules='acl = "write"
key_prefix "consul-snapshot/" {
  policy = "write"
}
session_prefix "" {
  policy = "write"
}
service_prefix "consul-snapshot" {
  policy = "write"
}'

  # Create a token with the snapshot agent policy.
  snapshot_token=$(consul acl token create \
    -description="Snapshot agent token" \
    -policy-name="snapshot-agent" \
    -format=json | jq -r '.SecretID')

  log "  Deploying snapshot agent token to all nodes."

  # Accept the bastion host key if not already known.
  if ! ssh-keygen -F "${bastion_ip}" >/dev/null 2>&1; then
    ssh-keyscan -H "${bastion_ip}" >>~/.ssh/known_hosts 2>/dev/null
  fi

  for ip in ${consul_ips}; do
    log "  Enabling snapshot agent on:" "${ip}"
    # shellcheck disable=SC2086
    ssh ${ssh_opts} -J "${ssh_user}@${bastion_ip}" "${ssh_user}@${ip}" \
      "printf 'CONSUL_HTTP_TOKEN=%s\n' '${snapshot_token}' | sudo tee /etc/consul.d/snapshot-token >/dev/null && sudo systemctl enable --now consul-snapshot-agent"
  done

  log "  Snapshot agent enabled on all nodes."
}

main() {
  set -ef

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
  bootstrap_acl
  configure_snapshots
}

main "$@"
