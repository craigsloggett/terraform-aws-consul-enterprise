resource "vault_mount" "consul_bootstrap" {
  path        = "kv/consul"
  type        = "kv-v2"
  description = "Infrastructure bootstrap secrets for Consul"
}
