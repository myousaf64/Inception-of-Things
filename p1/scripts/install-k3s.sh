#!/usr/bin/env bash
# Installs K3s on a p1 node.
#   ROLE=server  controller (control plane) advertised on NODE_IP
#   ROLE=agent   worker joining the server at SERVER_IP
# Required env: ROLE, NODE_IP, K3S_TOKEN, plus SERVER_IP for agents.
set -euo pipefail

K3S_VERSION="v1.36.5+k3s1"

: "${ROLE:?ROLE must be set to server or agent}"
: "${NODE_IP:?NODE_IP must be set}"
: "${K3S_TOKEN:?K3S_TOKEN must be set}"

case "$ROLE" in
  server) role_args="--write-kubeconfig-mode=644" ;;
  agent)  role_args="--server=https://${SERVER_IP:?SERVER_IP must be set for agents}:6443" ;;
  *)      echo "ROLE must be 'server' or 'agent', got '$ROLE'" >&2; exit 1 ;;
esac

# The private network NIC name depends on the box (eth1, enp0s8, ...): find it by IP.
iface=$(ip -o -4 addr show to "$NODE_IP" | awk '{ print $2 }')
if [ -z "$iface" ]; then
  echo "No network interface carries NODE_IP $NODE_IP" >&2
  exit 1
fi

# K3s docs recommend turning firewalld off rather than maintaining its rules.
if systemctl is-active --quiet firewalld; then
  systemctl disable --now firewalld
fi

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  INSTALL_K3S_EXEC="$ROLE --node-ip=$NODE_IP --flannel-iface=$iface $role_args" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -

if [ "$ROLE" = server ]; then
  echo "alias k=kubectl" > /etc/profile.d/k3s-alias.sh
fi
