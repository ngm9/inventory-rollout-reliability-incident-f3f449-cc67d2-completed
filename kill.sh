#!/usr/bin/env bash
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[cleanup] Starting Kubernetes/minikube cleanup..."

if command -v minikube >/dev/null 2>&1; then
  echo "[cleanup] Current minikube status:"
  minikube status || true
else
  echo "[cleanup] minikube is not installed; continuing idempotent cleanup."
fi

echo "[cleanup] Deleting all minikube profiles and cached state..."
minikube delete --all --purge || true
echo "[cleanup] Minikube deletion step finished."

echo "[cleanup] Removing task-generated local artifacts..."
rm -rf tmp logs .task-state || true
echo "[cleanup] Local artifact cleanup finished."

if command -v docker >/dev/null 2>&1; then
  echo "[cleanup] Pruning stopped Docker containers..."
  docker container prune -f || true
  echo "[cleanup] Pruning unused Docker networks..."
  docker network prune -f || true
  echo "[cleanup] Pruning unused Docker volumes..."
  docker volume prune -f || true
fi

echo "Cleanup completed successfully!"
exit 0
