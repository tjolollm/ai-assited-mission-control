# Mission Control architect agent

An [agentctl](https://github.com/digdir/digdir-agents) agent for the up-front architecture of this repository. It grills
you on a design until every decision is settled, records the decisions as [MADR](https://adr.github.io/madr/) ADRs in
`docs/adr/` in pull requests, and creates GitHub issues specified tightly enough that an implementing agent, such as
[mission-control-dev](../mission-control-dev), builds what you meant. Each issue passes a cold read by a fresh subagent
before it is created. It does not build or run the code.

| Variant | What it changes |
| --- | --- |
| (none) | The published image, cloning this repository at boot |
| `nested` | Sized to fit inside another agent, as `mission-control-architect-nested` |
| `nested-build` | `nested`, with the image built from this checkout, to try a change to it before CI publishes it |
| `worktree` | Mounts this checkout in place of a fresh clone, as `mission-control-architect-worktree` |

## Getting started

```sh
agentctl github login default   # the account it pushes ADRs, opens pull requests and creates issues as
cd agents/mission-control-architect/minimal
agentctl apply --wait
```

The image is built from [`Dockerfile`](Dockerfile) on the agentctl base image of release `v0.1.0-preview.15`, and
published to `ghcr.io/tjolollm/ai-assited-mission-control/mission-control-architect-minimal` by
[mission-control-architect-image.yml](../../.github/workflows/mission-control-architect-image.yml) when it changes on
`main`. Before that, `agentctl apply --variant nested-build` builds it on your machine, which needs Docker there.

The first session in the repository asks you to run `/setup-matt-pocock-skills` once, which records GitHub Issues as
the tracker in `docs/agents/` and the `ready-for-agent` label the issues get.

A variant of your own, such as `agent.mine.yaml`, which Git ignores, can extend the manifest. Keep credentials out of
it: they belong in `agentctl github login`.

## Inside the agent

[`instructions.md`](instructions.md), [`minimal/environment.md`](minimal/environment.md) and
[`improving.md`](improving.md) are its instructions, with [`worktree.md`](worktree.md) on the `worktree` variant.

Its own skills are [`madr-adr`](skills/madr-adr/SKILL.md), for ADRs and their pull requests, and
[`agent-ready-issue`](skills/agent-ready-issue/SKILL.md), for what an issue must say and its cold read. With them are
`grill-me`, `grilling`, `grill-with-docs`, `domain-modeling`, `to-spec`, `to-tickets`, `writing-for-agents` and
`setup-matt-pocock-skills`, pinned copies from [mattpocock/skills](https://github.com/mattpocock/skills) under its MIT
licence, as [`skills/VENDORED.md`](skills/VENDORED.md) describes.

A session goes `/grill-with-docs` → ADRs with `madr-adr` → `/to-spec` → `/to-tickets`, each issue checked with
`agent-ready-issue`.
