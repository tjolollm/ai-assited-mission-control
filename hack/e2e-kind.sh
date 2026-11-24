#!/usr/bin/env bash
# End-to-end test of the hello-world apps on a local kind cluster. Builds both images, loads them into the cluster,
# deploys them behind LoadBalancer services (addresses come from cloud-provider-kind) and checks that each answers
# GET / with exactly {"message":"hello, world"} at its LoadBalancer address.
#
#   hack/e2e-kind.sh                  # cluster e2e-<checkout directory>-<hash>, deleted afterwards
#   KEEP_CLUSTER=1 hack/e2e-kind.sh   # keep that cluster, to poke around; a later plain run reuses and deletes it
#   CLUSTER=foo hack/e2e-kind.sh      # cluster foo: created and deleted if missing, reused and kept if it exists
set -euo pipefail

cd "$(dirname "$0")/.."

APPS=(hello-go hello-rust)
WANT='{"message":"hello, world"}'

# The manifests are one Deployment and Service each, identical apart from the app name. Keep them that way, so a
# change to one, such as a probe or the preStop hook, is not forgotten in the other.
for app in "${APPS[@]:1}"; do
  if ! diff -u "deploy/kind/${APPS[0]}.yaml" <(sed "s/${app}/${APPS[0]}/g" "deploy/kind/${app}.yaml"); then
    echo "deploy/kind/${app}.yaml differs from deploy/kind/${APPS[0]}.yaml by more than the app name" >&2
    exit 1
  fi
done

# The default cluster is named after the checkout, so tasks in different worktrees do not share, or delete, one
# cluster: its directory name, cut to 30 characters, then a hash of its full path, so checkouts whose names agree in
# those 30 still differ. Only this script uses that name, so a cluster by it is the script's own to delete, even one
# an earlier KEEP_CLUSTER=1 run left.
checkout="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
checkout_name="$(basename "${checkout}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-\n' '-')"
checkout_hash="$(printf '%s' "${checkout}" | sha256sum | cut -c1-8)"
if [[ -n "${CLUSTER:-}" ]]; then
  default_name=0
else
  default_name=1
  CLUSTER="e2e-${checkout_name:0:30}-${checkout_hash}"
fi
CTX="kind-${CLUSTER}"

delete_cluster=0
workdir="$(mktemp -d)"
declare -A IMAGE
cleanup() {
  rm -rf "${workdir}"
  if ((delete_cluster)); then
    kind delete cluster --name "${CLUSTER}"
  fi
}
trap cleanup EXIT

# Tag each build with its image ID, so the deployment names exactly the image just built: a new build changes the pod
# template and rolls the pods, and an unchanged one leaves pods that already run it.
for app in "${APPS[@]}"; do
  docker build -t "localhost/${app}:e2e" "apps/${app}"
  id="$(docker image inspect -f '{{.Id}}' "localhost/${app}:e2e")"
  id="${id#sha256:}"
  IMAGE[${app}]="localhost/${app}:e2e-${id:0:12}"
  docker tag "localhost/${app}:e2e" "${IMAGE[${app}]}"
done

# Read the list whole before searching it: with pipefail, grep -q quitting at its first match could fail the pipe.
# -F, as a cluster name may hold a '.'.
clusters="$(kind get clusters 2>/dev/null)"
if grep -qxF "${CLUSTER}" <<<"${clusters}"; then
  if ((default_name)); then
    echo "Reusing cluster ${CLUSTER}, left by an earlier run of this script."
    [[ "${KEEP_CLUSTER:-0}" == 1 ]] || delete_cluster=1
  else
    echo "Reusing cluster ${CLUSTER}, named by CLUSTER; it is not this script's to delete."
  fi
else
  # Armed before creating, KEEP_CLUSTER or not, so a create that is interrupted or fails part way leaves nothing
  # behind for a later run to mistake for a working cluster.
  delete_cluster=1
  kind create cluster --name "${CLUSTER}" --wait 180s
  [[ "${KEEP_CLUSTER:-0}" != 1 ]] || delete_cluster=0
fi

for app in "${APPS[@]}"; do
  kind load docker-image "${IMAGE[${app}]}" --name "${CLUSTER}"
  # The cluster has its own copy now; drop the per-build tag here, so runs do not pile them up. The image itself
  # stays as localhost/<app>:e2e until the next build.
  docker rmi "${IMAGE[${app}]}" >/dev/null
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
  # The body goes to a file, not through $(...), which would drop a trailing newline the apps must not send.
  body="${workdir}/${app}.body"
  : >"${body}"
  for _ in $(seq 30); do
    # Bounded, so an address that drops packets costs seconds per try rather than the kernel's connect timeout.
    curl -fsSg --connect-timeout 2 --max-time 5 -o "${body}" "${url}" 2>/dev/null && break
    : >"${body}"
    sleep 2
  done
  # Compare the raw bytes: both apps send exactly this body, with no trailing newline.
  if cmp -s "${body}" <(printf '%s' "${WANT}"); then
    echo "PASS ${app} ${url} -> $(cat "${body}")"
  else
    echo "FAIL ${app} ${url}: got $(wc -c <"${body}") bytes, want ${#WANT}:"
    od -c "${body}" | head -5
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
