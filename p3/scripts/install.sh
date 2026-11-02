#!/usr/bin/env bash
# Installs what Part 3 needs on an Ubuntu host: Docker Engine, kubectl and k3d.
# Safe to re-run: tools that are already installed are skipped.
set -euo pipefail

K3D_VERSION="v5.9.0"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi
TARGET_USER=${SUDO_USER:-root} # the user who gets Docker access
ARCH=$(dpkg --print-architecture) # amd64 or arm64
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

install_docker() {
  if command -v docker >/dev/null; then
    echo "docker: already installed"
  else
    apt-get update -q
    apt-get install -y -q ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    # shellcheck source=/dev/null
    . /etc/os-release
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    apt-get update -q
    apt-get install -y -q docker-ce docker-ce-cli containerd.io
  fi
  systemctl enable --now docker
  if [ "$TARGET_USER" != root ] && ! id -nG "$TARGET_USER" | grep -qw docker; then
    usermod -aG docker "$TARGET_USER"
    echo "docker: added $TARGET_USER to the docker group (log out and back in, or run 'newgrp docker')"
  fi
}

install_kubectl() {
  if command -v kubectl >/dev/null; then
    echo "kubectl: already installed"
    return
  fi
  local version url
  version=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  url="https://dl.k8s.io/release/$version/bin/linux/$ARCH/kubectl"
  curl -fsSLo "$TMP/kubectl" "$url"
  echo "$(curl -fsSL "$url.sha256")  $TMP/kubectl" | sha256sum --check --quiet
  install -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
}

install_k3d() {
  if command -v k3d >/dev/null; then
    echo "k3d: already installed"
    return
  fi
  local base="https://github.com/k3d-io/k3d/releases/download/$K3D_VERSION"
  curl -fsSLo "$TMP/k3d-linux-$ARCH" "$base/k3d-linux-$ARCH"
  curl -fsSLo "$TMP/checksums.txt" "$base/checksums.txt"
  (cd "$TMP" && grep " k3d-linux-$ARCH\$" checksums.txt | sha256sum --check --quiet)
  install -m 0755 "$TMP/k3d-linux-$ARCH" /usr/local/bin/k3d
}

install_docker
install_kubectl
install_k3d

echo
docker --version
kubectl version --client
k3d version
