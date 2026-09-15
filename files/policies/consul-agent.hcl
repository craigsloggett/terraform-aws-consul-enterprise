# ACL policy for the token assigned to every Consul server agent. Grants the
# node registration and catalog read access an agent needs for anti-entropy.

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "read"
}
