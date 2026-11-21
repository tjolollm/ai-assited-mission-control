## Improving this agent

Your own definition is `agents/mission-control-dev` in ai-assited-mission-control, and its image is published by
`.github/workflows/mission-control-dev-image.yml` when a change to it reaches `main`. The `agent-definition` skill
applies to it. When the repository pins a tool version, in `go.mod`, `rust-toolchain.toml`, a `.terraform-version` or
its CI workflows, move the matching `ARG` in the `Dockerfile` with it.

To try a change in a nested agent, apply a variant from the task's worktree. `nested` runs the published image, and
`nested-build` builds it from the checkout, which a change to the `Dockerfile` or what it copies needs:

```sh
cd /home/agent/code/.worktrees/<task>/agents/mission-control-dev/minimal
agentctl apply --variant nested-build --name <task>-nested --wait
```
