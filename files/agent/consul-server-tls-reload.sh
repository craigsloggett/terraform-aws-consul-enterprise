#!/bin/sh
set -ef

# Atomic rename so the readers see either the old file or the new file,
# never a zero-byte file mid-write.
mv -f /opt/consul/tls/server.key.new /opt/consul/tls/server.key
mv -f /opt/consul/tls/ca.pem.new /opt/consul/tls/ca.pem
mv -f /opt/consul/tls/server.crt.new /opt/consul/tls/server.crt

# On the first render Consul is not running yet; start-consul.sh brings it up
# with these files already in place.
if systemctl is-active --quiet consul.service; then
  systemctl kill --signal=SIGHUP --kill-whom=main consul.service
fi
