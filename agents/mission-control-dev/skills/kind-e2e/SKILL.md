---
name: kind-e2e
description: Run Mission Control's end-to-end tests on a local Kubernetes cluster in kind, with LoadBalancer services from cloud-provider-kind, and apply its Terraform against that cluster. Use when a change must be shown working on Kubernetes, or when Terraform needs a cluster to plan or apply against.
---

# End-to-end tests on kind

When the repository has its own end-to-end setup, such as a `Makefile` target, a script under `hack/` or `test/e2e/`,
a kind configuration or a CI job that creates a cluster, use it, with the Kubernetes version it names. What follows is
for what it leaves out.

## A cluster per task

Name the cluster after the task, so tasks do not share one:

```sh
kind create cluster --name <task> --wait 180s            # kubectl's context becomes kind-<task>
kubectl --context kind-<task> get nodes
```

`kind create cluster --config <file>` takes the repository's kind configuration when it has one. Images you build
locally reach the cluster with `kind load docker-image <image> --name <task>`, after `docker build` (Podman) builds
them, and the cluster pulls public images itself.

## LoadBalancer services

cloud-provider-kind runs as a service on this machine, so a `type: LoadBalancer` service gets an address shortly after
it is created, on Podman's `kind` network, which you reach directly:

```sh
kubectl --context kind-<task> wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' service/<name> --timeout=120s
ip="$(kubectl --context kind-<task> get service <name> -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
curl -fsS "http://${ip}:<port>/"
```

No address after two minutes: read `journalctl -u cloud-provider-kind -n 50`.

## Terraform against the cluster

The Kubernetes and Helm providers take the cluster from kubeconfig, as `config_path = "~/.kube/config"` and
`config_context = "kind-<task>"`. Run `terraform init`, `terraform plan` and, for an end-to-end test, `terraform apply`,
and keep state local to the task's worktree. Never point Terraform at another cluster or a cloud account unless the
task says so.

## Clean up

Delete the cluster when the task is done, which also removes the Envoy containers cloud-provider-kind made for it:

```sh
kind delete cluster --name <task>
```

`podman ps -a --filter name=kindccm` lists the Envoy containers still there. One whose cluster is gone, such as after
`cloud-provider-kind.service` was restarted, can be removed with `podman rm -f`.
