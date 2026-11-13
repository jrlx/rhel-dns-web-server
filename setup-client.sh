#!/bin/bash
# setup-client.sh - configure the CLIENT to use the lab DNS server

set -euo pipefail
cd "$(dirname "$0")"

if [ "$EUID" -ne 0 ]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

source ./config.env
[ -f ./config.env.local ] && source ./config.env.local

# 1. Tools for testing
dnf install -y bind-utils curl

# 2. Use the lab DNS server
# Find the NetworkManager connection on the host-only interface.
CON="$(nmcli -g GENERAL.CONNECTION device show "$LAB_IFACE")"
if [ -z "$CON" ]; then
  echo "No connection found on $LAB_IFACE. Check LAB_IFACE in config.env.local." >&2
  exit 1
fi

# A negative priority makes the client use ONLY this DNS server,
# so the NAT adapter's DNS can't answer lab.test lookups instead.
nmcli connection modify "$CON" \
  ipv4.dns "$SERVER_IP" \
  ipv4.dns-search "$DOMAIN" \
  ipv4.dns-priority -10
nmcli connection up "$CON"

# 3. Trust the lab CA
# TODO (B): copy the CA certificate to /etc/pki/ca-trust/source/anchors/
#           and run update-ca-trust

# Quick self-test
echo "==> Lookups from the client:"
for name in "$SITE1" "$SITE2"; do
  printf '  %-25s -> %s\n' "$name" "$(dig "$name" +short)"
done
echo "==> Answering server:"
dig "$SITE1" | grep -E '^;; SERVER'

echo "==> Client setup complete."
