#!/usr/bin/env bash
# End-to-end test of the hello-world apps on a local kind cluster. Builds both images, loads them into the cluster,
# deploys them behind LoadBalancer services (addresses come from cloud-provider-kind) and checks that each answers
# GET / with {"message":"hello, world"} at its LoadBalancer address.
#
#   hack/e2e-kind.sh                          # cluster e2e-<checkout directory>-<hash>, created and deleted by the script
#   CLUSTER=foo hack/e2e-kind.sh              # a cluster the script did not create is reused and kept
#   KEEP_CLUSTER=1 hack/e2e-kind.sh           # keep the cluster the script created, to poke around
set -euo pipefail

cd "$(dirname "$0")/.."

# Name the cluster after the checkout, so tasks in different worktrees do not share, or delete, one cluster: its
# directory name, cut to 30 characters, then a hash of its full path, so checkouts whose names agree in those 30 still
# differ.
checkout="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
checkout_name="$(basename "${checkout}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-\n' '-')"
checkout_hash="$(printf '%s' "${checkout}" | sha256sum | cut -c1-8)"
CLUSTER="${CLUSTER:-e2e-${checkout_name:0:30}-${checkout_hash}}"
CTX="kind-${CLUSTER}"
APPS=(hello-go hello-rust)
WANT='{"message":"hello, world"}'

# Tag each build with its image ID, so the deployment names exactly the image just built: a new build changes the pod
# template and rolls the pods, and an unchanged one leaves pods that already run it.
declare -A IMAGE
for app in "${APPS[@]}"; do
  docker build -t "localhost/${app}:e2e" "apps/${app}"
  id="$(docker image inspect -f '{{.Id}}' "localhost/${app}:e2e")"
  id="${id#sha256:}"
  IMAGE[${app}]="localhost/${app}:e2e-${id:0:12}"
  docker tag "localhost/${app}:e2e" "${IMAGE[${app}]}"
done

# Read the list whole before searching it: with pipefail, grep -q quitting at its first match could fail the pipe.
clusters="$(kind get clusters 2>/dev/null)"
if grep -qx "${CLUSTER}" <<<"${clusters}"; then
  echo "Reusing cluster ${CLUSTER}, which this script did not create and will not delete."
else
  # Set before creating, so a create that is interrupted or fails part way leaves nothing behind for a later run to
  # mistake for a cluster someone made.
  if [[ "${KEEP_CLUSTER:-0}" != 1 ]]; then
    trap 'kind delete cluster --name "${CLUSTER}"' EXIT
  fi
  kind create cluster --name "${CLUSTER}" --wait 180s
fi

for app in "${APPS[@]}"; do
  kind load docker-image "${IMAGE[${app}]}" --name "${CLUSTER}"
  manifest="$(sed "s#image: localhost/${app}:e2e\$#image: ${IMAGE[${app}]}#" "deploy/kind/${app}.yaml")"
  if ! grep -qF "image: ${IMAGE[${app}]}" <<<"${manifest}"; then
    echo "deploy/kind/${app}.yaml does not name image localhost/${app}:e2e for the script to replace" >&2
    exit 1
  fi
  kubectl --context "${CTX}" apply -f - <<<"${manifest}"
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
  # An IPv6 address goes in brackets in a URL.
  if [[ "${ip}" == *:* ]]; then url="http://[${ip}]/"; else url="http://${ip}/"; fi
  body=""
  for _ in $(seq 30); do
    # Bounded, so an address that drops packets costs seconds per try rather than the kernel's connect timeout.
    body="$(curl -fsSg --connect-timeout 2 --max-time 5 "${url}" 2>/dev/null)" && break
    sleep 2
  done
  # Compare the raw bytes: both apps send exactly the same body.
  if [[ "${body}" == "${WANT}" ]]; then
    echo "PASS ${app} ${url} -> ${body}"
  else
    echo "FAIL ${app} ${url} -> ${body:-<no response>}"
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
