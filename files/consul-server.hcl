# Read own bootstrap secrets
path "kv/consul/data/bootstrap/gossip" {
  capabilities = ["read"]
}
path "kv/consul/data/bootstrap/ca" {
  capabilities = ["read"]
}
path "kv/consul/data/bootstrap/bootstrap-token" {
  capabilities = ["read"]
}

# Issue own server cert from pki_consul
path "pki_consul/issue/consul-server" {
  capabilities = ["create", "update"]
}
