#!/usr/bin/env bash
# End-to-end test of the hello-world apps on a local kind cluster. Builds both images, loads them into the cluster,
# deploys them behind LoadBalancer services (addresses come from cloud-provider-kind) and checks that each answers
# GET / with {"message":"hello, world"} at its LoadBalancer address.
#
#   hack/e2e-kind.sh                 # cluster "hello-world", deleted afterwards
#   CLUSTER=foo KEEP_CLUSTER=1 hack/e2e-kind.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CLUSTER="${CLUSTER:-hello-world}"
CTX="kind-${CLUSTER}"
APPS=(hello-go hello-rust)

if [[ "${KEEP_CLUSTER:-0}" != 1 ]]; then
  trap 'kind delete cluster --name "${CLUSTER}"' EXIT
fi

for app in "${APPS[@]}"; do
  docker build -t "localhost/${app}:e2e" "apps/${app}"
done

kind get clusters | grep -qx "${CLUSTER}" || kind create cluster --name "${CLUSTER}" --wait 180s

for app in "${APPS[@]}"; do
  kind load docker-image "localhost/${app}:e2e" --name "${CLUSTER}"
  kubectl --context "${CTX}" apply -f "deploy/kind/${app}.yaml"
done

failed=0
for app in "${APPS[@]}"; do
  kubectl --context "${CTX}" rollout status "deployment/${app}" --timeout=120s
  kubectl --context "${CTX}" wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' "service/${app}" --timeout=120s
  ip="$(kubectl --context "${CTX}" get service "${app}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  body=""
  for _ in $(seq 30); do
    body="$(curl -fsS "http://${ip}/" 2>/dev/null)" && break
    sleep 2
  done
  if [[ "$(jq -c . <<<"${body:-null}")" == '{"message":"hello, world"}' ]]; then
    echo "PASS ${app} http://${ip}/ -> ${body}"
  else
    echo "FAIL ${app} http://${ip}/ -> ${body:-<no response>}"
    failed=1
  fi
done

kubectl --context "${CTX}" get pods,services -o wide
exit "${failed}"
