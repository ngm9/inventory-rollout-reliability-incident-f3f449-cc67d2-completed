#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

NAMESPACE="inventory"

echo "== Workload summary =="
kubectl get deployment,pods,service -n "$NAMESPACE" -o wide || true

echo
echo "== Rollout conditions =="
kubectl get deployment inventory-api -n "$NAMESPACE" \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,UPDATED:.status.updatedReplicas,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas' || true

echo
echo "== Service backend discovery =="
kubectl get endpointslice -n "$NAMESPACE" \
  -l kubernetes.io/service-name=inventory-api -o wide || true

echo
echo "== Recent namespace events =="
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 25 || true
