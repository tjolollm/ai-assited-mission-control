## This machine

- Go is in `/usr/local/go`, with `GOPATH` at `~/go`. A newer `go` line in `go.mod` downloads that toolchain on first
  use. Rust comes from rustup, so a `rust-toolchain.toml` selects its own toolchain. Cargo builds into
  `~/.cache/cargo-target`, which `CARGO_TARGET_DIR` names, rather than a checkout's `target/`.
- Containers run on Podman. The `docker` command and `docker compose` run Podman, and Docker API clients reach it at
  `/run/docker.sock`. Do not install Docker beside it.
- kind uses Podman, as `KIND_EXPERIMENTAL_PROVIDER=podman` says. Leave that set: Podman's `docker` command answers
  some of Docker's queries differently, and cloud-provider-kind then fails to find a cluster's API server.
- `cloud-provider-kind.service` runs all the time and gives the LoadBalancer services of every kind cluster an address
  on Podman's `kind` network, which this machine reaches directly. `journalctl -u cloud-provider-kind` shows its log.
  Do not start a second one.
- This agent has no browser and no desktop. When a task needs one, such as a screenshot of a web page, say so.
