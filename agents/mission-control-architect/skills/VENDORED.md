# Vendored skills

These skills are copied from [mattpocock/skills](https://github.com/mattpocock/skills), under its MIT licence in
[LICENSE.mattpocock-skills](LICENSE.mattpocock-skills), at commit `abeeaf95660ba9e8b7c753eb38f441ca707a8823`
(2026-11-19). Each folder is the upstream folder of the same name:

| Skill | Upstream path |
| --- | --- |
| `grill-me` | `skills/productivity/grill-me` |
| `grilling` | `skills/productivity/grilling` |
| `grill-with-docs` | `skills/engineering/grill-with-docs` |
| `domain-modeling` | `skills/engineering/domain-modeling` |
| `to-spec` | `skills/engineering/to-spec` |
| `to-tickets` | `skills/engineering/to-tickets` |
| `writing-for-agents` | `skills/productivity/writing-for-agents` |
| `setup-matt-pocock-skills` | `skills/engineering/setup-matt-pocock-skills` |

`madr-adr` and `agent-ready-issue` are this repository's own.

## Local changes

- `domain-modeling/ADR-FORMAT.md` points at `madr-adr` instead of upstream's one-paragraph ADR, since Mission
  Control's ADRs are MADR. Its rule for when an ADR is worth writing is upstream's.

## Updating

Copy the folders above from a later commit, apply the local changes again, and change the commit here. Read upstream's
`CHANGELOG.md` between the two commits first: a renamed skill, or one that now calls another, changes this list and the
`skills` of `minimal/agent.yaml`.
