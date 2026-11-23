# The image of the Mission Control developer agent, built on the agentctl base image of release
# v0.1.0-preview.15. It adds Go, Rust, Terraform and a local Kubernetes in kind, with cloud-provider-kind for
# LoadBalancer services, and agentctl, so the agent can try changes to its own definition in a nested agent. rtk and
# Ponytail save tokens: rtk condenses the output of the agent's shell commands, and Ponytail keeps the code it writes
# small. home/.claude/settings.json turns both on.
#
# The repository pins no tool versions yet. When it does, in go.mod, rust-toolchain.toml, .terraform-version or its
# CI workflows, move the ARGs below to match, with the checksums of the new downloads.
FROM ghcr.io/digdir/agentctl-base:ubuntu-26.04-v0.1.0-preview.15@sha256:dd96a8413e1890b58ae4cde092bfc8b97fcb9e221822fdcb8bb3dc26466be949 AS minimal

# The base ends as the unprivileged agent user; installing packages needs root again.
USER root

# Native build tools for Go's cgo and Rust crates that link OpenSSL, and unzip for HashiCorp's releases.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        build-essential \
        libssl-dev \
        pkg-config \
        rustup \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Rust. A rust-toolchain.toml in a checkout selects its own toolchain; the agent user owns RUSTUP_HOME, so one pinned
# ahead of this image installs on first use instead of failing.
ARG RUST_VERSION=1.100.0
ENV RUSTUP_HOME=/usr/local/rustup
RUN rustup set profile minimal \
    && rustup default "${RUST_VERSION}" \
    && rustup component add clippy rustfmt \
    && chown -R agent:agent /usr/local/rustup \
    && rm -rf /root/.cargo /root/.rustup

# Podman, with the `docker` command and Docker Compose. kind runs its Kubernetes nodes as containers on it, and a
# nested agentd builds agent images with it.
RUN agent-feature install containers

# kind mounts /lib/modules into its nodes, and the agent's kernel has its modules built in, with no such directory.
RUN mkdir -p /lib/modules

ARG TARGETARCH
ARG GO_VERSION=1.27.4
ARG TERRAFORM_VERSION=1.17.2
ARG TFLINT_VERSION=0.66.0
ARG KUBECTL_VERSION=1.37.2
ARG KIND_VERSION=0.33.0
ARG CLOUD_PROVIDER_KIND_VERSION=0.12.0
ARG HELM_VERSION=4.3.2
ARG GOLANGCI_LINT_VERSION=2.15.0
ARG YQ_VERSION=4.54.1
ARG RTK_VERSION=1.2.1
ARG PONYTAIL_VERSION=5.3.3

RUN set -eu; \
    case "${TARGETARCH}" in \
        amd64) \
            GO_SHA256=7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840; \
            TERRAFORM_SHA256=e6f16b2f0b137ee5729caa8c4e79a3bae4ee261acd198a1fcfa8584a6296605b; \
            TFLINT_SHA256=22be11cadc25cd02401e94c0ccc91aa63467debb8485c2a755d98f4c0a9d1e2e; \
            KUBECTL_SHA256=c04487523e7aa7d1493f7808174c899db93d7a9cf57531420cd76b9bd415f8f4; \
            KIND_SHA256=aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d; \
            CLOUD_PROVIDER_KIND_SHA256=5716aca8f01a85172c12f3b6329c70f151bec02c91b6f600c9f230845ee138e6; \
            HELM_SHA256=d1c0278d46beab79582d7e50f5b3dc206944ba8e577cde618513fd07daa53983; \
            GOLANGCI_LINT_SHA256=9b7fe6a6bf6334b98decf8d86b11415ea7889afdabdd1959fdce23af2a9ebcea; \
            YQ_SHA256=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f; \
            RTK_TARGET=x86_64-unknown-linux-musl; \
            RTK_SHA256=44aa460c4827d206d11405c652832c9f7082edccfbc3a9f15a69a851e8a9e8b4 ;; \
        arm64) \
            GO_SHA256=3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92; \
            TERRAFORM_SHA256=858e08c181a76b6b223e8c767a8e983922eebe2d062db949a2de66ce040c368c; \
            TFLINT_SHA256=1105a0a5ddee7cdac7957a3475571a946b839192ea1bc0c722c6c4686001067e; \
            KUBECTL_SHA256=fcc16f63186659d9722014b7e02d5fdd2d4e669cb8c0ab66365d7d3b8ba03509; \
            KIND_SHA256=20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2; \
            CLOUD_PROVIDER_KIND_SHA256=8c13bb92ec621d23a77397fe894ac36c10e9d22b92c04fe54d8c9256355d3263; \
            HELM_SHA256=df31cb61680ef728f82c770e5280dd565617bee6b039d37e85c677288be4bbb0; \
            GOLANGCI_LINT_SHA256=b4d8f17068b35ee6060cc2f69a16fb48740d706fbba81661c318649c114a6998; \
            YQ_SHA256=189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b; \
            RTK_TARGET=aarch64-unknown-linux-musl; \
            RTK_SHA256=b01860ae2d3f44e0f7fc4431a95dd66b29b4bd87ec7f5e60aff13681b05db5dd ;; \
        *) echo "unsupported target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    fetch() { curl -fsSL "$1" -o "${tmp}/$2" && echo "$3  ${tmp}/$2" | sha256sum -c -; }; \
    fetch "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" go.tar.gz "${GO_SHA256}"; \
    tar -xzf "${tmp}/go.tar.gz" -C /usr/local; \
    fetch "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
        terraform.zip "${TERRAFORM_SHA256}"; \
    unzip -q "${tmp}/terraform.zip" terraform -d /usr/local/bin; \
    fetch "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip" \
        tflint.zip "${TFLINT_SHA256}"; \
    unzip -q "${tmp}/tflint.zip" tflint -d /usr/local/bin; \
    fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" kubectl "${KUBECTL_SHA256}"; \
    install -m 0755 "${tmp}/kubectl" /usr/local/bin/kubectl; \
    fetch "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-${TARGETARCH}" kind "${KIND_SHA256}"; \
    install -m 0755 "${tmp}/kind" /usr/local/bin/kind; \
    fetch "https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v${CLOUD_PROVIDER_KIND_VERSION}/cloud-provider-kind_${CLOUD_PROVIDER_KIND_VERSION}_linux_${TARGETARCH}.tar.gz" \
        cloud-provider-kind.tar.gz "${CLOUD_PROVIDER_KIND_SHA256}"; \
    tar -xzf "${tmp}/cloud-provider-kind.tar.gz" -C /usr/local/bin cloud-provider-kind; \
    fetch "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" helm.tar.gz "${HELM_SHA256}"; \
    tar -xzf "${tmp}/helm.tar.gz" -C "${tmp}" "linux-${TARGETARCH}/helm"; \
    install -m 0755 "${tmp}/linux-${TARGETARCH}/helm" /usr/local/bin/helm; \
    fetch "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${TARGETARCH}.tar.gz" \
        golangci-lint.tar.gz "${GOLANGCI_LINT_SHA256}"; \
    tar -xzf "${tmp}/golangci-lint.tar.gz" -C "${tmp}" "golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${TARGETARCH}/golangci-lint"; \
    install -m 0755 "${tmp}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${TARGETARCH}/golangci-lint" /usr/local/bin/golangci-lint; \
    fetch "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" yq "${YQ_SHA256}"; \
    install -m 0755 "${tmp}/yq" /usr/local/bin/yq; \
    fetch "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-oss-${RTK_TARGET}.tar.gz" \
        rtk.tar.gz "${RTK_SHA256}"; \
    tar -xzf "${tmp}/rtk.tar.gz" -C "${tmp}" rtk; \
    install -m 0755 "${tmp}/rtk" /usr/local/bin/rtk; \
    rm -rf "${tmp}"

# Ponytail, a Claude Code plugin that steers the agent to the least code a task needs, as a local marketplace that
# home/.claude/settings.json enables, so every session loads this version without fetching it.
ARG PONYTAIL_SHA256=a1409db9ef8ba2556aed6aa3766c381cd633c9f2f9d1c4515fec44df5bb446a3
RUN set -eu; \
    tmp="$(mktemp -d)"; \
    curl -fsSL "https://github.com/DietrichGebert/ponytail/archive/refs/tags/v${PONYTAIL_VERSION}.tar.gz" \
        -o "${tmp}/ponytail.tar.gz"; \
    echo "${PONYTAIL_SHA256}  ${tmp}/ponytail.tar.gz" | sha256sum -c -; \
    mkdir -p /usr/local/share/claude-plugins/ponytail; \
    tar -xzf "${tmp}/ponytail.tar.gz" -C /usr/local/share/claude-plugins/ponytail \
        --strip-components=1 --no-same-owner; \
    rm -rf "${tmp}"

# agentctl and agentd of the same release as the base, to try changes to this agent's definition in a nested agent.
COPY --from=ghcr.io/digdir/agentctl:v0.1.0-preview.15@sha256:1bc767955b6740c4b65e402332e8099154a0da8a4a80ae8f778182647dcdf40e \
    /agentctl /agentd /usr/local/bin/

# Podman's socket for the agent user from the first boot, which kind and cloud-provider-kind need.
COPY common/podman-socket-agent.conf /etc/systemd/system/podman.socket.d/40-agent-group.conf

# cloud-provider-kind runs all the time, so every kind cluster gets LoadBalancer IPs and Gateway API support.
COPY common/cloud-provider-kind.service /etc/systemd/system/cloud-provider-kind.service
RUN systemctl enable cloud-provider-kind.service

# The repositories to clone into /home/agent/code at boot.
COPY common/workspace.list /etc/agent-workspace.d/mission-control.list

# kind and cloud-provider-kind drive Podman's CLI rather than Docker's, whose output Podman's `docker` differs from.
ENV KIND_EXPERIMENTAL_PROVIDER=podman
# Caches stay in the agent's home, on its own disk, out of a mounted checkout.
ENV GOPATH=/home/agent/go
ENV CARGO_HOME=/home/agent/.cargo
ENV CARGO_TARGET_DIR=/home/agent/.cache/cargo-target
ENV PATH=/home/agent/.local/bin:/home/agent/go/bin:/home/agent/.cargo/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# The checks run with a HOME of their own, since terraform and golangci-lint write caches to it, and root's would lock
# the agent out of /home/agent.
RUN export HOME="$(mktemp -d)" \
    && go version \
    && rustc --version \
    && cargo clippy --version \
    && terraform version \
    && tflint --version \
    && kubectl version --client \
    && kind version \
    && helm version \
    && golangci-lint version \
    && yq --version \
    && rtk --version \
    && test -f /usr/local/share/claude-plugins/ponytail/.claude-plugin/plugin.json \
    && agentctl --version \
    && rm -rf "${HOME}" /root/.cache /root/go \
    && agent-image-check

USER agent
