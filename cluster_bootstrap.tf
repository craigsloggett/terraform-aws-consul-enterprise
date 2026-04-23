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
