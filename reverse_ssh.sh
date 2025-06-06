#!/bin/bash
source ~/.ssh-tunnel.env

ssh -N -R 0.0.0.0:$REMOTE_PORT:localhost:$LOCAL_PORT \
  -i "$SSH_KEY" "$EC2_USER@$EC2_HOST"
