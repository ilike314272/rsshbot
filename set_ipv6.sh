#!/bin/bash
source ~/.ssh-tunnel.env

# Make sure file exists
if [ ! -f "$IPV6_FILE_PATH" ]; then
  echo "IPv6 file not found: $IPV6_FILE_PATH"
  exit 1
fi

# Extract IPv6 from the file
IPV6=$(grep 'IPv6:' "$IPV6_FILE_PATH" | awk '{print $2}')

# Validate
if [[ "$IPV6" =~ ^([0-9a-fA-F:]+:+)+[0-9a-fA-F]+$ ]]; then
  echo "Assigning IPv6 address $IPV6 to $NETWORK_INTERFACE"

  # Remove any existing non-link-local addresses first
  sudo ip -6 addr flush dev "$NETWORK_INTERFACE" scope global

  # Assign the new address
  sudo ip -6 addr add "$IPV6"/64 dev "$NETWORK_INTERFACE"

  # Optional: Add route
  sudo ip -6 route add default via fe80::1 dev "$NETWORK_INTERFACE" || true
else
  echo "No valid IPv6 found in $IPV6_FILE_PATH"
  exit 1
fi
