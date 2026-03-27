#!/bin/sh
# Usage: ./validate-deployment.sh us-east-1

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  bastion_ip=$(terraform output -raw bastion_public_ip)
  consul_url=$(terraform output -raw consul_url)
  consul_ips=$(terraform output -json consul_private_ips | jq -r '.[]')
  tg_arn=$(terraform output -raw consul_target_group_arn)
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
  log "  Consul URL:" "${consul_url}"
  log "  SSH user:" "${ssh_user}"
  # shellcheck disable=SC2086
  log "  Consul nodes:" "$(printf '%s ' ${consul_ips})"
}

check_target_health() {
  log "Checking NLB target group health."

  aws elbv2 describe-target-health \
    --region "${region}" \
    --target-group-arn "${tg_arn}" \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State,Reason:TargetHealth.Reason}' \
    --output table
}

validate_node() {
  log "Checking consul node:" "$1"

  # shellcheck disable=SC2086
  ssh ${ssh_opts} \
    -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ${ssh_user}@${bastion_ip}" \
    "${ssh_user}@$1" sh -s <<'REMOTE'
    printf 'Cloud-init status: %s\n' "$(cloud-init status 2>/dev/null || echo 'unknown')"

    printf 'EBS volume mounted: '
    if mountpoint -q /opt/consul/data; then echo "yes"; else echo "NO"; fi

    printf 'Consul binary: '
    if command -v consul >/dev/null 2>&1; then consul version; else echo "NOT FOUND"; fi

    printf 'TLS CA cert: '
    if sudo test -f /opt/consul/tls/ca.crt; then echo "present"; else echo "MISSING"; fi

    printf 'TLS server cert: '
    if sudo test -f /opt/consul/tls/server.crt; then echo "present"; else echo "MISSING"; fi

    printf 'TLS server key: '
    if sudo test -f /opt/consul/tls/server.key; then echo "present"; else echo "MISSING"; fi

    printf 'Consul config: '
    if [ -f /etc/consul.d/consul.hcl ]; then echo "present"; else echo "MISSING"; fi

    printf 'Consul license: '
    if [ -f /opt/consul/consul.hclic ]; then echo "present"; else echo "MISSING"; fi

    printf 'Snapshot agent config: '
    if [ -f /etc/consul.d/snapshot-agent.hcl ]; then echo "present"; else echo "MISSING"; fi

    printf 'Consul service enabled: '
    if systemctl is-enabled consul >/dev/null 2>&1; then echo "yes"; else echo "NO"; fi

    printf 'Consul service running: '
    if systemctl is-active consul >/dev/null 2>&1; then echo "yes"; else echo "no"; fi

    printf 'Snapshot agent running: '
    if systemctl is-active consul-snapshot-agent >/dev/null 2>&1; then echo "yes"; else echo "no (enable after ACL bootstrap)"; fi
REMOTE
}

main() {
  set -ef

  region="${1:?Usage: $0 <region>}"
  ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o BatchMode=yes -o LogLevel=ERROR"

  # Colors are automatically disabled if output is not a terminal.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  read_terraform_outputs
  check_target_health

  for ip in ${consul_ips}; do
    validate_node "${ip}"
  done

  log "Validation complete."
}

main "$@"
