# SSM Parameter Store (cluster coordination)

resource "aws_ssm_parameter" "consul_cluster_state" {
  name        = "/${var.project_name}/consul/bootstrap/cluster/state"
  type        = "String"
  value       = "Uninitialized"
  description = "Bootstrap Initialization State Flag (Uninitialized | Ready)"

  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-cluster-state" })
}

# SSM Parameter Store (PKI coordination)

resource "aws_ssm_parameter" "consul_pki_state" {
  name        = "/${var.project_name}/consul/bootstrap/pki/state"
  type        = "String"
  value       = "Uninitialized"
  description = "Bootstrap PKI State Flag (Uninitialized | Ready)"

  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-pki-state" })
}

resource "aws_ssm_parameter" "consul_pki_intermediate_ca_csr" {
  name        = "/${var.project_name}/consul/bootstrap/pki/intermediate-csr"
  type        = "String"
  value       = "Uninitialized"
  description = "Bootstrap PKI Intermediate CA CSR"

  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-pki-intermediate-ca-csr" })
}

resource "aws_ssm_parameter" "consul_tls_ca_bundle" {
  name        = "/${var.project_name}/consul/tls/ca-bundle"
  type        = "String"
  value       = "Uninitialized"
  description = "Consul PKI TLS CA bundle (intermediate CA + root CA chain)"

  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-tls-ca-bundle" })
}

# Secrets Manager (signed intermediate CA certificate)

resource "aws_secretsmanager_secret" "consul_pki_intermediate_ca_signed_csr" {
  name_prefix = "${var.project_name}-consul-pki-intermediate-ca-signed-csr-"
  description = "Signed Consul Intermediate CA Certificate and Chain"

  tags = merge(var.common_tags, { Name = "${var.project_name}-consul-pki-intermediate-ca-signed-csr" })
}
