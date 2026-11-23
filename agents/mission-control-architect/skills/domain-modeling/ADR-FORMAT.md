# ADR Format

> Changed for Mission Control from upstream `mattpocock/skills`: this repository writes its ADRs in MADR, as the
> `madr-adr` skill describes. See `../VENDORED.md`.

ADRs live in `docs/adr/`, numbered in sequence: `0001-slug.md`, `0002-slug.md`, and so on. Write each one with the
`madr-adr` skill, which holds the template, the numbering and the status rules.

## When to offer an ADR

All three of these must be true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If a decision is easy to reverse, skip it. If it's not surprising, nobody will wonder why. If there was no real
alternative, there's nothing to record beyond "we did the obvious thing". When the user asks for an ADR anyway, write
it: the decision is theirs.
