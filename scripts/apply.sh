#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

command -v kubectl >/dev/null 2>&1 || {
  echo "[apply] kubectl is required." >&2
  exit 1
}

kubectl get --raw=/readyz >/dev/null

echo "[apply] Applying namespaces..."
kubectl apply -f manifests/namespace.yaml

echo "[apply] Applying runtime configuration..."
kubectl apply -f manifests/configmap.yaml

echo "[apply] Applying workload and Service..."
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml

echo "[apply] Confirming that starter objects were created..."
kubectl get deployment inventory-api -n inventory >/dev/null
kubectl get service inventory-api -n inventory >/dev/null

echo "[apply] Current object status:"
kubectl get deployment,pods,service -n inventory -o wide || true

echo "[apply] Workload seed completed. Runtime health is not used as an apply gate."
