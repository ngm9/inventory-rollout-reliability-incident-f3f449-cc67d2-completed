#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

NAMESPACE="checkout"
PROBE_NAME="checkout-network-test"
TARGET_URL="http://inventory-api.inventory.svc.cluster.local:8080/api/v1/reservations/health"

cleanup() {
  kubectl delete pod "$PROBE_NAME" -n "$NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! kubectl get --raw=/readyz >/dev/null 2>&1; then
  echo "[reproduce] Kubernetes API is unavailable." >&2
  exit 2
fi

cleanup

echo "[reproduce] Sending a checkout-side request through the inventory Service..."
if ! kubectl run "$PROBE_NAME" \
  -n "$NAMESPACE" \
  --restart=Never \
  --image=busybox:1.36.1 \
  --command -- /bin/sh -ec \
  "response=\$(wget -qO- --timeout=5 '$TARGET_URL'); printf '%s\n' \"\$response\"; echo \"\$response\" | grep -q '\"status\":\"ok\"'" >/dev/null; then
  echo "[reproduce] Could not create the in-cluster request Pod." >&2
  exit 2
fi

phase=""
for attempt in $(seq 1 25); do
  phase="$(kubectl get pod "$PROBE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  case "$phase" in
    Succeeded|Failed)
      break
      ;;
  esac
  sleep 1
done

echo "[reproduce] Probe output:"
kubectl logs "$PROBE_NAME" -n "$NAMESPACE" 2>/dev/null || true

if [[ "$phase" == "Succeeded" ]]; then
  echo "[reproduce] Reservation Service request succeeded."
  exit 0
fi

echo "[reproduce] Reservation Service request failed with Pod phase: ${phase:-unknown}" >&2
kubectl describe pod "$PROBE_NAME" -n "$NAMESPACE" 2>/dev/null | tail -n 30 >&2 || true
exit 1
