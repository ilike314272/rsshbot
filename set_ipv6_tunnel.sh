#!/bin/bash
set -e
source ~/rsshbot/ssh-tunnel.env

HOST_ID=$(hostname)
MACHINE_FOLDER="$REPO_DIR/$HOST_ID"
IPV6_FILE="$MACHINE_FOLDER/ipv6.txt"
WG_CONFIG="$MACHINE_FOLDER/wg0.conf"
CURRENT_WG_CONFIG="/etc/wireguard/wg0.conf"

echo "[*] Pulling latest from GitHub"
cd "$REPO_DIR" || exit 1
git pull origin "$GIT_BRANCH"

# === STEP 1: SET IPV6 IF NEEDED ===
if [ ! -f "$IPV6_FILE" ]; then
  echo "[!] No ipv6.txt found for $HOST_ID"
  exit 1
fi

NEW_IPV6=$(grep -oP '([0-9a-fA-F:]+:+)+[0-9a-fA-F]+' "$IPV6_FILE" | head -1)
CURRENT_IPV6=$(ip -6 addr show dev "$NETWORK_INTERFACE" scope global | grep inet6 | awk '{print $2}' | cut -d'/' -f1 | head -1)

if [ "$NEW_IPV6" != "$CURRENT_IPV6" ]; then
  echo "[*] Changing IPv6 from $CURRENT_IPV6 to $NEW_IPV6"
  sudo ip -6 addr flush dev "$NETWORK_INTERFACE" scope global
  sudo ip -6 addr add "$NEW_IPV6"/64 dev "$NETWORK_INTERFACE"
  sudo ip -6 route add default via fe80::1 dev "$NETWORK_INTERFACE" || true
else
  echo "[✓] IPv6 is already correctly set to $NEW_IPV6"
fi

# === STEP 2: SET WIREGUARD IF CHANGED ===
if [ ! -f "$WG_CONFIG" ]; then
  echo "[!] No wg0.conf found for $HOST_ID"
  exit 1
fi

if ! cmp -s "$WG_CONFIG" "$CURRENT_WG_CONFIG"; then
  echo "[*] WireGuard config has changed — updating"
  sudo cp "$WG_CONFIG" "$CURRENT_WG_CONFIG"
  sudo chmod 600 "$CURRENT_WG_CONFIG"
  sudo systemctl restart wg-quick@wg0
else
  echo "[✓] WireGuard config already up to date"
fi

# === STEP 3: SETUP REVERSE SSH ===
# Check if autossh is already running
REVERSE_CMD="autossh -M 0 -f -N -R 0.0.0.0:$REMOTE_PORT:localhost:$LOCAL_PORT -i $SSH_KEY $E
