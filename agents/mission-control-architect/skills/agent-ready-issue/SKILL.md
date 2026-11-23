---
name: agent-ready-issue
description: Make a Mission Control issue specific enough that an implementing agent builds exactly what was decided, and check it with a cold read before it is published. Use before creating or editing any issue, including those to-spec and to-tickets publish.
---

# Issues an agent can implement without guessing

An issue you write is the whole of what an implementing agent, such as `mission-control-dev`, knows of the session
that produced it. Every gap is a guess it makes, and a guess is where its solution parts from the one the user wanted.
This skill adds to what `to-spec` and `to-tickets` write; follow them, then this.

## What each issue has

Under the headings of the `to-spec` or `to-tickets` template, each issue has:

- **Decisions:** a link to each ADR that governs it, with one line on what that ADR means for this issue. An ADR whose
  pull request is still open is linked by its pull request too, with: _Do not start until #N is merged._
- **What to build:** behaviour, in the words of `GLOSSARY.md`. Name the modules and interfaces it changes, and the
  shape of any interface it adds, such as a type, an API route and its payload, or a CLI command and its flags, rather
  than leaving them to be invented. Leave out file paths, as `to-spec` says, except for a file that is the subject of
  the issue.
- **Acceptance criteria:** each one observable, and checkable by running something, such as _`GET /missions/{id}`
  returns 404 with body `{"error":"mission_not_found"}` for an unknown id_, not _handles missing missions_. Include the
  failure and edge cases the grilling settled.
- **How to verify:** the commands that show the criteria hold, and what each must show. Take them from the
  repository's CI workflows and from what `mission-control-dev` runs: `go test ./...`, `golangci-lint run`,
  `cargo test`, `cargo clippy --all-targets -- -D warnings`, `terraform validate`, `terraform plan` against kind, and
  the end-to-end tests on kind. Name the tests to add, by what they test, at the seam `to-spec` chose.
- **Out of scope:** what it must not do, especially what a capable agent would add unasked, such as a refactor next
  door, a configuration option or a fallback the decision rejected. Name the rejected options of its ADRs here.
- **Blocked by:** as `to-tickets` says, as GitHub's native dependencies.

## The cold read

Before you publish an issue, have it read by a reader who was not in the session:

1. Start a subagent with a fresh context, such as Claude Code's `Agent` tool with a general-purpose agent. Give it only
   the issue's text, the ADRs it links, and the path of the checkout. Do not give it the conversation, or what you
   think the answer is.
2. Ask it to plan the implementation, and to list every point where it had to choose between readings, invent a name,
   a shape or a behaviour, or assume something the issue does not say, and how it would check that it is done.
3. For each point, fix the issue when the session already settled it. When it did not, ask the user: that is a
   decision, not yours to make. Then read again with a new subagent, until a read finds nothing that matters.

Without subagents, do the read yourself, as the implementer, from the issue alone, and say in your report to the user
that the read was not cold.

## Publishing

- Create issues as `to-tickets` and `docs/agents/issue-tracker.md` say, with `gh`, blockers first, each a sub-issue
  of the spec's issue, labelled `ready-for-agent`. Before the first `gh issue create` of a session, check with
  `gh repo view --json nameWithOwner` that it files into `tjolollm/ai-assited-mission-control`, or the repository the
  user named.
- Then give the user the list: number, title, what blocks it, and the points the cold reads raised and how each was
  settled.
