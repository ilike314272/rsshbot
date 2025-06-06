#!/bin/bash
set -e

source ~/.ssh-tunnel.env

HOST_ID=$(hostname)
MACHINE_FOLDER="$REPO_DIR/$HOST_ID"
IPV6_FILE="$MACHINE_FOLDER/ipv6.txt"
WG_CONFIG="$MACHINE_FOLDER/wg0.conf"
CURRENT_WG_CONFIG="/etc/wireguard/wg0.conf"

# === STEP 1: Ensure SSH key exists ===
if [ ! -f "$SSH_KEY" ]; then
  echo "[*] Generating SSH key for EC2 reverse tunnel..."
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
fi

# === STEP 2: Clone or pull repo ===
if [ ! -d "$REPO_DIR" ]; then
  echo "[*] Cloning IP sync repo..."
  git clone -b "$GIT_BRANCH" "$GITHUB_REPO" "$REPO_DIR"
else
  echo "[*] Pulling latest IP config from repo..."
  cd "$REPO_DIR" || exit 1
  git pull origin "$GIT_BRANCH"
fi

# === STEP 3: Compare and apply IPv6 if changed ===
if [ ! -f "$IPV6_FILE" ]; then
  echo "[!] Missing ipv6.txt in $MACHINE_FOLDER"
  exit 1
fi

NEW_IPV6=$(grep -oP '([0-9a-fA-F:]+:+)+[0-9a-fA-F]+' "$IPV6_FILE" | head -1)
CURRENT_IPV6=$(ip -6 addr show dev "$NETWORK_INTERFACE" scope global | grep inet6 | awk '{print $2}' | cut -d'/' -f1 | head -1)

if [ "$NEW_IPV6" != "$CURRENT_IPV6" ]; then
  echo "[*] Updating IPv6: $CURRENT_IPV6 → $NEW_IPV6"
  sudo ip -6 addr flush dev "$NETWORK_INTERFACE" scope global
  sudo ip -6 addr add "$NEW_IPV6"/64 dev "$NETWORK_INTERFACE"
  sudo ip -6 route add default via fe80::1 dev "$NETWORK_INTERFACE" || true
else
  echo "[✓] IPv6 is already up to date"
fi

# === STEP 4: Compare and apply WireGuard config ===
if [ ! -f "$WG_CONFIG" ]; then
  echo "[!] Missing wg0.conf in $MACHINE_FOLDER"
  exit 1
fi

if ! cmp -s "$WG_CONFIG" "$CURRENT_WG_CONFIG"; then
  echo "[*] WireGuard config changed — applying update"
  sudo cp "$WG_CONFIG" "$CURRENT_WG_CONFIG"
  sudo chmod 600 "$CURRENT_WG_CONFIG"
  sudo systemctl restart wg-quick@wg0
else
  echo "[✓] WireGuard config is already up to date"
fi

# === STEP 5: Upload SSH key to EC2 ===
PUB_KEY=$(cat "$SSH_KEY.pub")

echo "[*] Uploading SSH public key to EC2 (if not already added)..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$EC2_USER@$EC2_HOST" "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && grep -qxF '$PUB_KEY' ~/.ssh/authorized_keys || echo '$PUB_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

# === STEP 6: Start reverse SSH tunnel ===
REVERSE_CMD="autossh -M 0 -f -N -R 0.0.0.0:$REMOTE_PORT:localhost:$LOCAL_PORT -i $SSH_KEY $EC2_USER@$EC2_HOST"

if ! pgrep -f "$REVERSE_CMD" > /dev/null; then
  echo "[*] Starting reverse SSH tunnel to $EC2_HOST:$REMOTE_PORT"
  $REVERSE_CMD
else
  echo "[✓] Reverse SSH tunnel already running"
fi

echo "[✓] All tasks completed successfully"

