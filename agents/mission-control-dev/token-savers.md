## Command output and code size

Two tools save tokens here. Both are on in every Claude Code session.

- **rtk** rewrites your shell commands, such as `git status` or `cargo test`, through `rtk`, which condenses their
  output while keeping every error, failure and warning. Treat it as the complete result: run commands normally, and
  batch related ones into one call. Truncated output says how to get the rest. Run a command as `rtk bypass <cmd>`
  only when its result is unusable: empty when output was clearly expected, contradicting its exit code, or garbled.
  `rtk gain` shows what it saved. The file tools `Read`, `Grep` and `Glob` pass through it unchanged.
- **Ponytail** steers you to the least new code a task needs: reuse what the repository has, the standard library,
  then an installed dependency. It never skips validation, error handling, security, tests or the checks above that
  finish a task. `/ponytail lite|full|ultra|off` sets its level, and `/ponytail-review` reviews a change.
