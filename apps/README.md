# Apps

Two small web services that answer `GET /` with the same JSON body, byte for byte, with no trailing newline:

```json
{"message":"hello, world"}
```

Any other path answers `404`, and any other method on `/` answers `405`. Both listen on port `8080`, or on `PORT` when
it is set. On `SIGTERM` or `SIGINT` they finish the requests in flight and exit.

| App | Language | Stack |
| --- | --- | --- |
| [`hello-go`](hello-go) | Go | standard library `net/http` |
| [`hello-rust`](hello-rust) | Rust | [axum](https://github.com/tokio-rs/axum) on tokio |

## Build and test

```sh
cd apps/hello-go   && go build ./... && go test ./... && golangci-lint run
cd apps/hello-rust && cargo build && cargo test && cargo clippy --all-targets -- -D warnings && cargo fmt --check
```

CI runs the same checks in [`.github/workflows/apps.yml`](../.github/workflows/apps.yml), then the end-to-end test
below. The Rust toolchain is pinned in [`hello-rust/rust-toolchain.toml`](hello-rust/rust-toolchain.toml).

## Run locally

```sh
(cd apps/hello-go && go run .)       # then: curl localhost:8080/
(cd apps/hello-rust && cargo run)    # then: curl localhost:8080/
```

## End-to-end on kind

[`hack/e2e-kind.sh`](../hack/e2e-kind.sh) builds both images, loads them into a kind cluster, deploys them from
[`deploy/kind/`](../deploy/kind) behind `LoadBalancer` services, and checks each one's response at its LoadBalancer
address. It needs kind, kubectl, jq, a container engine, and
[cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) to give the services their addresses.

```sh
hack/e2e-kind.sh                  # cluster e2e-<checkout directory>, created and deleted by the script
KEEP_CLUSTER=1 hack/e2e-kind.sh   # keep the cluster it created, to poke around
CLUSTER=mine hack/e2e-kind.sh     # use an existing cluster, which the script leaves in place
```

An app that fails is reported with its pod description and logs, and the script still checks the others.
