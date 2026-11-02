#!/usr/bin/env bash
# Creates the K3d cluster, installs Argo CD and lets it deploy the app from GitHub.
# Run install.sh first. Safe to re-run.
set -euo pipefail

CLUSTER="iot"
ARGOCD_VERSION="v3.5.6"
CONFS_DIR="$(cd "$(dirname "$0")/../confs" && pwd)"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not reachable. Run install.sh, then log out and back in" \
       "(or run 'newgrp docker') so your user is in the docker group." >&2
  exit 1
fi

if k3d cluster get "$CLUSTER" >/dev/null 2>&1; then
  echo "Cluster '$CLUSTER' already exists"
else
  # The app's LoadBalancer Service listens on 8888; expose it on the host's port 8888.
  k3d cluster create "$CLUSTER" --port "8888:8888@loadbalancer" --wait
fi
kubectl config use-context "k3d-$CLUSTER"

kubectl apply -f "$CONFS_DIR/namespaces.yaml"

# Server-side apply: the Argo CD CRDs are too large for client-side apply annotations.
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
kubectl -n argocd wait --for=condition=available deployment --all --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

kubectl apply -f "$CONFS_DIR/application.yaml"

echo "Waiting for Argo CD to deploy the app into namespace dev..."
for _ in $(seq 60); do
  kubectl -n dev get deployment wil-playground >/dev/null 2>&1 && break
  sleep 5
done
kubectl -n dev wait --for=condition=available deployment/wil-playground --timeout=300s

password=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
cat <<EOF

Argo CD UI: kubectl port-forward -n argocd svc/argocd-server 8080:443
            then open https://localhost:8080  (user: admin, password: $password)
App:        curl http://localhost:8888/
EOF
