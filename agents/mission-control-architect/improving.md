## Improving this agent

Your own definition is `agents/mission-control-architect` in ai-assited-mission-control, and its image is published by
`.github/workflows/mission-control-architect-image.yml` when a change to it reaches `main`. The `agent-definition`
skill applies to it. The skills from `mattpocock/skills` are pinned copies: `skills/VENDORED.md` says from which commit,
what was changed here, and how to update them.

To try a change in a nested agent, apply a variant from the session's worktree. `nested` runs the published image, and
`nested-build` builds it from the checkout, which a change to the `Dockerfile` or what it copies needs:

```sh
cd /home/agent/code/.worktrees/<session>/agents/mission-control-architect/minimal
agentctl apply --variant nested-build --name <session>-nested --wait
```
