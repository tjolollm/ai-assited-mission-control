# Mission Control developer agent

An [agentctl](https://github.com/digdir/digdir-agents) agent that develops this repository: Go, Rust and Terraform, with
a local Kubernetes in [kind](https://kind.sigs.k8s.io/) and
[cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) for LoadBalancer services. It builds,
runs the unit tests and lints, checks and plans Terraform, and runs the end-to-end tests on a kind cluster, and shows
the results in its pull requests.

| Variant | What it changes |
| --- | --- |
| (none) | The published image, cloning this repository at boot |
| `nested` | Sized to fit inside another agent, as `mission-control-dev-nested` |
| `nested-build` | `nested`, with the image built from this checkout, to try a change to it before CI publishes it |
| `worktree` | Mounts this checkout in place of a fresh clone, as `mission-control-dev-worktree` |

## Getting started

```sh
agentctl github login default                                  # the account it pushes and opens pull requests as
agentctl secret set anthropic-api-key --hosts api.anthropic.com   # optional, for the Claude API
cd agents/mission-control-dev/minimal
agentctl apply --wait
```

The image is built from [`Dockerfile`](Dockerfile) on the agentctl base image of release `v0.1.0-preview.15`, and
published to `ghcr.io/tjolollm/ai-assited-mission-control/mission-control-dev-minimal` by
[mission-control-dev-image.yml](../../.github/workflows/mission-control-dev-image.yml) when it changes on `main`. Before
that, `agentctl apply --variant nested-build` builds it on your machine, which needs Docker there.

A variant of your own, such as `agent.mine.yaml`, which Git ignores, can extend the manifest. Keep credentials out of
it: they belong in `agentctl github login` and `agentctl secret set`.

## Inside the agent

[`instructions.md`](instructions.md), [`minimal/environment.md`](minimal/environment.md) and
[`improving.md`](improving.md) are its instructions, with [`worktree.md`](worktree.md) on the `worktree` variant. Its
skills are [`kind-e2e`](skills/kind-e2e/SKILL.md), for end-to-end tests on kind, and
[`pr-evidence`](skills/pr-evidence/SKILL.md), for what its pull requests show.
