---
name: madr-adr
description: Write or change an architecture decision record in docs/adr/ in MADR format, and open its pull request. Use whenever an ADR is recorded, edited, superseded or deprecated in Mission Control, including when domain-modeling or grill-with-docs offers one.
---

# ADRs in MADR

Mission Control's ADRs are [MADR 4](https://adr.github.io/madr/) files in `docs/adr/`, one decision each. Write one
only once the user has agreed the decision in the grilling session: an ADR records a decision, it does not make one.

## File

- **Name:** `docs/adr/NNNN-short-title-in-kebab-case.md`. `NNNN` is one more than the highest number in `docs/adr/` on
  `origin/main` **and** in the open pull requests that add ADRs (`gh pr list --search "docs/adr in:files"`, then read
  their files), so two sessions do not take the same number. Create `docs/adr/` with the first ADR.
- **Title:** the problem it solves and the solution found, such as `Use NATS JetStream for mission telemetry`.
- **Status:** `accepted` when the user agreed it in the session, `proposed` when they want the team to decide in the
  pull request. A decision that replaces an earlier one sets the earlier one to `superseded by ADR-NNNN` in the same
  pull request, and links back to it.
- **About the project only:** drivers, consequences and confirmation are about Mission Control, its code, team and
  deployment, never about the agent writing the ADR or the machine it runs on, such as what this sandbox has
  installed.
- **Words:** the terms of `GLOSSARY.md`. A term the decision introduces goes into the glossary in the same pull
  request, as `domain-modeling` describes.

## Template

Keep every section that says something and drop the optional ones that would only repeat. **Confirmation** is not
optional here: it is what lets an implementing agent and a reviewer check the decision was followed.

```md
---
status: accepted
date: YYYY-MM-DD
decision-makers: <GitHub handles of who decided>
consulted: <optional>
informed: <optional>
---

# <Title>

## Context and Problem Statement

<2–4 sentences: the situation, the forces at play and the question being decided. Link the issue or discussion that
started it.>

## Decision Drivers

* <driver, such as a requirement, constraint or quality attribute>

## Considered Options

* <option 1>
* <option 2>

## Decision Outcome

Chosen option: "<option>", because <justification tied to the drivers>.

### Consequences

* Good, because <consequence>
* Bad, because <consequence, and what is done about it>

### Confirmation

<How anyone can check the code follows this decision: commands to run and what they show, such as a test, a lint
rule, a `terraform plan` that shows no other resource type, or an architecture test that fails on a forbidden import.
Prefer a check that fails on its own when the decision is broken over one someone has to remember to read.>

## Pros and Cons of the Options

### <option 1>

* Good, because <argument>
* Neutral, because <argument>
* Bad, because <argument>

### <option 2>

...

## More Information

<Links to the issues it gives rise to, related ADRs, and when to revisit it.>
```

## Pull request

1. Work in a worktree on a branch `adr/NNNN-short-title`, from the current `origin/main`.
2. Commit the ADR, with the glossary changes and any ADR it supersedes.
3. Open the pull request with `gh pr create`, titled `ADR-NNNN: <title>`. Its body says in two or three sentences what
   was decided and why, links the issues that implement it once they exist, and lists the questions that are still
   open, if any. An ADR with open questions is `proposed`.
4. Give the user its link. Issues that implement the ADR link its file on the branch and the pull request, and say it
   must be merged before they are started, as the `agent-ready-issue` skill describes.
