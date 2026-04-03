#!/bin/sh
# Usage: ./initialize-cluster.sh

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  bastion_ip=$(cd "${repo_root}" && terraform output -raw bastion_public_ip)
  consul_ips=$(cd "${repo_root}" && terraform output -json consul_private_ips | jq -r '.[]')
  consul_url=$(cd "${repo_root}" && terraform output -raw consul_url)
  consul_token_secret_arn=$(cd "${repo_root}" && terraform output -raw consul_token_secret_arn)
  ami_name=$(cd "${repo_root}" && terraform output -raw ec2_ami_name)
  nomad_server_service_name=$(cd "${repo_root}" && terraform output -raw nomad_server_service_name)
  nomad_client_service_name=$(cd "${repo_root}" && terraform output -raw nomad_client_service_name)
  nomad_snapshot_service_name=$(cd "${repo_root}" && terraform output -raw nomad_snapshot_service_name)

  first_consul_ip=$(printf '%s\n' "${consul_ips}" | head -1)

  case "${ami_name}" in
    *ubuntu*) ssh_user="ubuntu" ;;
    *debian*) ssh_user="admin" ;;
    *)
      log "ERROR: Unsupported AMI:" "${ami_name}"
      exit 1
      ;;
  esac

  log "  Bastion IP:" "${bastion_ip}"
  log "  Consul nodes:" "$(printf '%s\n' "${consul_ips}" | tr '\n' ' ')"
  log "  SSH user:" "${ssh_user}"
}

remote_exec() {
  target_ip="${1:?target IP required}"
  shift
  # shellcheck disable=SC2086
  ssh ${ssh_opts} -J "${ssh_user}@${bastion_ip}" "${ssh_user}@${target_ip}" "$@"
}

wait_for_consul() {
  log "Waiting for Consul to be reachable."

  attempts=0
  max_attempts=30
  while ! remote_exec "${first_consul_ip}" \
    "sudo curl -sf --cacert /opt/consul/tls/ca.crt --cert /opt/consul/tls/server.crt --key /opt/consul/tls/server.key https://127.0.0.1:8501/v1/status/leader" >/dev/null 2>&1; do
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
  init_file="$(cd "$(dirname "$0")" && pwd)/consul-init.json"

  # Check if ACL system is already bootstrapped.
  if [ -f "${init_file}" ]; then
    log "ACL system already bootstrapped (${init_file} exists)."
    return
  fi

  log "Bootstrapping Consul ACL system."

  if remote_exec "${first_consul_ip}" \
    "sudo consul acl bootstrap -format=json -ca-file=/opt/consul/tls/ca.crt -client-cert=/opt/consul/tls/server.crt -client-key=/opt/consul/tls/server.key -http-addr=https://127.0.0.1:8501" \
    >"${init_file}" 2>/dev/null; then
    log "ACL bootstrap complete."
    log "IMPORTANT: The bootstrap token has been saved to consul-init.json." "" "!!"
    log "           Store this file securely and delete it from disk." "" "  "
  else
    log "ERROR: ACL bootstrap failed (system may already be bootstrapped)."
    rm -f "${init_file}"
    exit 1
  fi
}

configure_agent_tokens() {
  log "Configuring Consul agent tokens on all nodes."

  init_file="$(cd "$(dirname "$0")" && pwd)/consul-init.json"
  bootstrap_token=$(jq -r '.SecretID' "${init_file}")

  # Create the consul-server-agent policy (idempotent — ignore error if it already exists).
  curl -sf \
    -X PUT "${consul_url}/v1/acl/policy" \
    -H "X-Consul-Token: ${bootstrap_token}" \
    --data '{
      "Name": "consul-server-agent",
      "Rules": "node_prefix \"\" { policy = \"write\" }\nservice_prefix \"\" { policy = \"read\" }"
    }' >/dev/null 2>&1 || true

  # Create an agent token with the policy.
  agent_token=$(curl -sf \
    -X PUT "${consul_url}/v1/acl/token" \
    -H "X-Consul-Token: ${bootstrap_token}" \
    --data '{
      "Description": "Consul server agent token",
      "Policies": [{"Name": "consul-server-agent"}]
    }' | jq -r '.SecretID')

  if [ -z "${agent_token}" ] || [ "${agent_token}" = "null" ]; then
    log "ERROR: Failed to create Consul agent token."
    exit 1
  fi

  for ip in ${consul_ips}; do
    log "  Setting agent token on ${ip}."
    remote_exec "${ip}" \
      "sudo consul acl set-agent-token \
        -ca-file=/opt/consul/tls/ca.crt \
        -client-cert=/opt/consul/tls/server.crt \
        -client-key=/opt/consul/tls/server.key \
        -http-addr=https://127.0.0.1:8501 \
        -token=${bootstrap_token} \
        agent ${agent_token}"
  done

  log "Agent tokens configured on all nodes."
}

create_nomad_token() {
  init_file="$(cd "$(dirname "$0")" && pwd)/consul-init.json"
  bootstrap_token=$(jq -r '.SecretID' "${init_file}")

  # Skip if the secret already contains a real token.
  current_value=$(remote_exec "${first_consul_ip}" \
    "aws secretsmanager get-secret-value \
      --secret-id '${consul_token_secret_arn}' \
      --region us-east-1 \
      --query SecretString --output text" 2>/dev/null || true)

  if [ -n "${current_value}" ] && [ "${current_value}" != "PLACEHOLDER" ]; then
    log "Nomad token already exists in Secrets Manager, skipping."
    return
  fi

  log "Creating Consul ACL policy and token for Nomad."

  # Create the nomad-agent policy (idempotent — ignore error if it already exists).
  curl -sf \
    -X PUT "${consul_url}/v1/acl/policy" \
    -H "X-Consul-Token: ${bootstrap_token}" \
    --data '{
      "Name": "nomad-agent",
      "Rules": "node_prefix \"\" { policy = \"write\" }\nservice_prefix \"\" { policy = \"read\" }\nservice \"'"${nomad_server_service_name}"'\" { policy = \"write\" }\nservice \"'"${nomad_client_service_name}"'\" { policy = \"write\" }\nservice \"'"${nomad_snapshot_service_name}"'\" { policy = \"write\" }\nagent_prefix \"\" { policy = \"read\" }\nsession_prefix \"\" { policy = \"write\" }\nkey_prefix \"nomad-snapshot/\" { policy = \"write\" }"
    }' >/dev/null 2>&1 || true

  # Create the token with the policy.
  nomad_token=$(curl -sf \
    -X PUT "${consul_url}/v1/acl/token" \
    -H "X-Consul-Token: ${bootstrap_token}" \
    --data '{
      "Description": "Nomad agent token",
      "Policies": [{"Name": "nomad-agent"}]
    }' | jq -r '.SecretID')

  if [ -z "${nomad_token}" ] || [ "${nomad_token}" = "null" ]; then
    log "ERROR: Failed to create Nomad ACL token."
    exit 1
  fi

  log "Storing Nomad token in Secrets Manager."

  remote_exec "${first_consul_ip}" \
    "aws secretsmanager put-secret-value \
      --secret-id '${consul_token_secret_arn}' \
      --secret-string '${nomad_token}' \
      --region us-east-1" >/dev/null

  log "Nomad token created and stored in Secrets Manager."
}

configure_snapshot_agent() {
  log "Configuring snapshot agent token on all nodes."

  init_file="$(cd "$(dirname "$0")" && pwd)/consul-init.json"
  bootstrap_token=$(jq -r '.SecretID' "${init_file}")

  for ip in ${consul_ips}; do
    log "  Writing snapshot token on ${ip}."
    remote_exec "${ip}" \
      "sudo sed -i 's|^CONSUL_HTTP_TOKEN=.*|CONSUL_HTTP_TOKEN=${bootstrap_token}|' /opt/consul/snapshot-token && sudo systemctl enable --now consul-snapshot-agent"
  done

  log "Snapshot agent started on all nodes."
}

main() {
  set -ef

  ssh_opts="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o LogLevel=ERROR"

  # Colors are automatically disabled if output is not a terminal.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  read_terraform_outputs
  wait_for_consul
  bootstrap_acl
  configure_agent_tokens
  create_nomad_token
  configure_snapshot_agent
}

main "$@"
