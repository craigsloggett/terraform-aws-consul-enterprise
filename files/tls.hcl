tls {
  defaults {
    ca_file         = "/opt/consul/tls/ca.crt"
    cert_file       = "/opt/consul/tls/server.crt"
    key_file        = "/opt/consul/tls/server.key"
    verify_incoming = true
    verify_outgoing = true
    tls_min_version = "TLSv1_3"
  }
  https {
    verify_incoming = false
  }
  internal_rpc {
    verify_server_hostname = true
  }
}
