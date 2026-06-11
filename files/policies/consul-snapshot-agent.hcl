# Least-privilege ACL policy for the Consul snapshot agent, per the snapshot
# agent documentation. acl:write is required because snapshots contain ACL
# tokens with unredacted secrets.

acl = "write"

# Leader election lock between the snapshot agent instances.
key "consul-snapshot/lock" {
  policy = "write"
}

# Sessions are created against the local agent's node name, which is the EC2
# instance ID, so a prefix rule is required.
session_prefix "" {
  policy = "write"
}

# The snapshot agent registers itself into the catalog.
service "consul-snapshot" {
  policy = "write"
}
