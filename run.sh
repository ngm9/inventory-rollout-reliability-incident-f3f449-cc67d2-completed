#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[run] Checking required client tools..."
command -v kubectl >/dev/null 2>&1 || {
  echo "[run] kubectl is required but was not found." >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "[run] curl is required but was not found." >&2
  exit 1
}

if ! command -v minikube >/dev/null 2>&1; then
  echo "[run] Installing minikube..."
  curl https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -o /usr/local/bin/minikube && chmod +x /usr/local/bin/minikube
else
  echo "[run] minikube is already installed."
fi

echo "[run] Starting the pinned single-node Kubernetes cluster..."
minikube start --driver=docker --force --cpus=2 --memory=1800mb --kubernetes-version=v1.31.14 --wait=apiserver

echo "[run] Waiting for the Kubernetes API and control-plane node..."
api_ready=0
for attempt in $(seq 1 60); do
  if kubectl get --raw=/readyz >/dev/null 2>&1 && kubectl get nodes -o name 2>/dev/null | grep -q '^node/'; then
    api_ready=1
    break
  fi
  sleep 2
done

if [[ "$api_ready" -ne 1 ]]; then
  echo "[run] Kubernetes API or control-plane node did not become available." >&2
  minikube status || true
  exit 1
fi

kubectl get nodes

chmod +x scripts/apply.sh scripts/reproduce.sh scripts/status.sh kill.sh || true

echo "[run] Applying the incident workload..."
./scripts/apply.sh

echo "[run] Starter workload applied. Its unhealthy state is intentional."
echo "[run] Use the provided status and reproduction scripts to begin diagnosis."

# --- Kubernetes Dashboard tab (platform port 8001) --------------------------
# Served at the ROOT of :8001 via port-forward, because the assessment UI builds
# a tab URL as https://<port>-<sandbox>.e2b.app and cannot append a path or a
# #fragment. Detached, so it costs this script's boot budget nothing — the tab
# becomes live roughly 40s after the environment starts.
cat > /tmp/dashboard-tab.sh <<'DASHBOARD_TAB'
#!/usr/bin/env bash
set -u
minikube addons enable dashboard >/dev/null 2>&1
kubectl -n kubernetes-dashboard rollout status deploy/kubernetes-dashboard --timeout=300s >/dev/null 2>&1

# Open on the workload's namespace, not `default` — `default` is empty here, so
# the dashboard looks broken until you find the namespace selector. Resolved
# from the cluster (the namespace that actually holds a Deployment) so this
# keeps working if the namespace is renamed.
NS=$(kubectl get deploy -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' 2>/dev/null \
     | grep -vE '^(kube-system|kubernetes-dashboard)$' | head -1)
if [ -z "$NS" ]; then
  NS=$(kubectl get ns -o name 2>/dev/null | sed 's|namespace/||' \
       | grep -vE '^(default|kube-system|kube-public|kube-node-lease|kubernetes-dashboard)$' | head -1)
fi
if [ -n "$NS" ]; then
  kubectl -n kubernetes-dashboard create configmap kubernetes-dashboard-settings \
    --from-literal=_global="{\"defaultNamespace\":\"$NS\",\"itemsPerPage\":10}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
fi

# port-forward dies if the dashboard pod restarts; re-establish it.
while true; do
  kubectl port-forward -n kubernetes-dashboard --address 0.0.0.0 \
    svc/kubernetes-dashboard 8001:80 >/dev/null 2>&1
  sleep 2
done
DASHBOARD_TAB
chmod +x /tmp/dashboard-tab.sh
nohup setsid /tmp/dashboard-tab.sh >/tmp/dashboard.log 2>&1 &
