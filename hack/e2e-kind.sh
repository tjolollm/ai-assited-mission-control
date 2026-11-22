#!/usr/bin/env bash
# End-to-end test of the hello-world apps on a local kind cluster. Builds both images, loads them into the cluster,
# deploys them behind LoadBalancer services (addresses come from cloud-provider-kind) and checks that each answers
# GET / with {"message":"hello, world"} at its LoadBalancer address.
#
#   hack/e2e-kind.sh                          # cluster e2e-<checkout directory>, created and deleted by the script
#   CLUSTER=foo hack/e2e-kind.sh              # a cluster the script did not create is reused and kept
#   KEEP_CLUSTER=1 hack/e2e-kind.sh           # keep the cluster the script created, to poke around
set -euo pipefail

cd "$(dirname "$0")/.."

# Name the cluster after the checkout, so tasks in different worktrees do not share, or delete, one cluster.
default_cluster="e2e-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-\n' '-')"
CLUSTER="${CLUSTER:-${default_cluster:0:40}}"
CTX="kind-${CLUSTER}"
APPS=(hello-go hello-rust)
WANT='{"message":"hello, world"}'

for app in "${APPS[@]}"; do
  docker build -t "localhost/${app}:e2e" "apps/${app}"
done

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER}"; then
  echo "Reusing cluster ${CLUSTER}, which this script did not create and will not delete."
else
  kind create cluster --name "${CLUSTER}" --wait 180s
  if [[ "${KEEP_CLUSTER:-0}" != 1 ]]; then
    trap 'kind delete cluster --name "${CLUSTER}"' EXIT
  fi
fi

for app in "${APPS[@]}"; do
  kind load docker-image "localhost/${app}:e2e" --name "${CLUSTER}"
  existed=0
  kubectl --context "${CTX}" get "deployment/${app}" >/dev/null 2>&1 && existed=1
  kubectl --context "${CTX}" apply -f "deploy/kind/${app}.yaml"
  if ((existed)); then
    # Pick up the image just loaded, which the running pods have under the same tag.
    kubectl --context "${CTX}" rollout restart "deployment/${app}"
  fi
done

# Shows why an app failed, before the cluster goes away.
diagnose() {
  local app="$1"
  kubectl --context "${CTX}" describe pods -l "app=${app}" || true
  kubectl --context "${CTX}" logs -l "app=${app}" --all-containers --tail=50 || true
}

failed=()
for app in "${APPS[@]}"; do
  if ! kubectl --context "${CTX}" rollout status "deployment/${app}" --timeout=120s ||
    ! kubectl --context "${CTX}" wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' "service/${app}" --timeout=120s; then
    echo "FAIL ${app}: not ready or no LoadBalancer address"
    diagnose "${app}"
    failed+=("${app}")
    continue
  fi
  ip="$(kubectl --context "${CTX}" get service "${app}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  body=""
  for _ in $(seq 30); do
    body="$(curl -fsS "http://${ip}/" 2>/dev/null)" && break
    sleep 2
  done
  # Compare the raw bytes: both apps send exactly the same body.
  if [[ "${body}" == "${WANT}" ]]; then
    echo "PASS ${app} http://${ip}/ -> ${body}"
  else
    echo "FAIL ${app} http://${ip}/ -> ${body:-<no response>}"
    diagnose "${app}"
    failed+=("${app}")
  fi
done

kubectl --context "${CTX}" get pods,services -o wide
if ((${#failed[@]})); then
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo "All ${#APPS[@]} apps passed."
