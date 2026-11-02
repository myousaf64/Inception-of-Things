#!/usr/bin/env bash
# Installs a single-node K3s server, then deploys the three apps and their Ingress.
# Required env: NODE_IP, CONFS_DIR (directory of manifests copied in by Vagrant).
set -euo pipefail

K3S_VERSION="v1.36.5+k3s1"

: "${NODE_IP:?NODE_IP must be set}"
: "${CONFS_DIR:?CONFS_DIR must be set}"

# Vagrant re-copies the manifests on every provision; remove them so the next copy isn't nested.
trap 'rm -rf "$CONFS_DIR"' EXIT

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
  INSTALL_K3S_EXEC="server --node-ip=$NODE_IP --flannel-iface=$iface --write-kubeconfig-mode=644" \
  sh -

echo "alias k=kubectl" > /etc/profile.d/k3s-alias.sh

# sudo's secure_path leaves out /usr/local/bin, where K3s puts kubectl.
export PATH="/usr/local/bin:$PATH"
kubectl apply -f "$CONFS_DIR"
kubectl wait --for=condition=available deployment --all --timeout=300s
