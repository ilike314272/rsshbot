#!/bin/bash
source ~/.ssh-tunnel.env

COMMIT_MSG="Update IPs on $(hostname) at $(date)"

# Clone if not already
if [ ! -d "$REPO_DIR" ]; then
  git clone "$GITHUB_REPO" "$REPO_DIR"
fi

cd "$REPO_DIR" || exit 1

# Get current IPs
IPV4=$(curl -s https://api.ipify.org)

echo "IPv4: $IPV4" > "public_ips_$(hostname).txt"

git pull origin "$GIT_BRANCH"
git add "$IP_FILE"
git commit -m "$COMMIT_MSG"
git push origin "$GIT_BRANCH"
