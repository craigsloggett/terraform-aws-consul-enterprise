# Resources used only during the initial Consul cluster bootstrap process.
#
# Unlike a Vault cluster bootstrapping its own PKI, no temporary TLS materials
# are needed here: the Vault Agent on every node issues a server certificate
# from the external Vault PKI before Consul ever starts.

# Initialization Coordination SSM Parameters

resource "aws_ssm_parameter" "bootstrap_consul_cluster_state" {
  name        = var.bootstrap.ssm_parameter.consul_cluster_state_name
  type        = "String"
  value       = "Uninitialized"
  description = "Bootstrap Initialization State Flag"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "bootstrap_instance_id" {
  name        = var.bootstrap.ssm_parameter.instance_id_name
  type        = "String"
  value       = "Uninitialized"
  description = "EC2 instance ID of the elected bootstrap node"

  lifecycle {
    ignore_changes = [value]
  }
}
