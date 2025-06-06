#!/bin/bash
set -e
source ~/.ssh-tunnel.env

# == CONFIG ==
HOST_ID=$(hostname)
MACHINE_FOLDER="$REPO_DIR/$HOST_ID"
IPV6_FILE="$MACHINE_FOLDER/ipv6.txt"
WG_CONFIG="$MACHINE_FOLDER/wg0.conf"

echo "[*] Pulling latest from GitHub"
cd "$REPO_DIR" || exit 1
git pull origin "$GIT_BRANCH"

# == STEP 1: Set Static IPv6 ==
if [ ! -f "$IPV6_FILE" ]; then
  echo "[!] No ipv6.txt found for $HOST_ID"
  exit 1
fi

IPV6=$(grep -oP '([0-9a-fA-F:]+:+)+[0-9a-fA-F]+' "$IPV6_FILE" | head -1)
if [[ -z "$IPV6" ]]; then
  echo "[!] Invalid or empty IPv6 address in $IPV6_FILE"
  exit 1
fi

echo "[*] Setting IPv6 address $IPV6 on $NETWORK_INTERFACE"

# Flush old and assign new
sudo ip -6 addr flush dev "$NETWORK_INTERFACE" scope global
sudo ip -6 addr add "$IPV6"/64 dev "$NETWORK_INTERFACE"

# Optional: Add default route
sudo ip -6 route add default via fe80::1 dev "$NETWORK_INTERFACE" || true

# == STEP 2: Apply WireGuard Config ==
if [ ! -f "$WG_CONFIG" ]; then
  echo "[!] No wg0.conf found for $HOST_ID"
  exit 1
fi

echo "[*] Applying WireGuard configuration"
sudo cp "$WG_CONFIG" /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl restart wg-quick@wg0

echo "[✓] Done setting IPv6 and WireGuard"
