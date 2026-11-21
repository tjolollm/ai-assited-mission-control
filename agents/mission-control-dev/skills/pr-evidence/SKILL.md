---
name: pr-evidence
description: Show reviewers of a Mission Control pull request what was run and what it showed, from unit tests and lints to terraform plan and the end-to-end run on kind. Use when opening or updating a pull request.
---

# Evidence in a pull request

A reviewer knows only the pull request, and should see what you ran without running it. Its body has a **Verification**
section with, for each check you ran, the command, the revision it ran on, and the result:

- **Build, unit tests and lints:** the summary lines of `go test`, `cargo test`, `golangci-lint` and `cargo clippy`,
  such as `ok ./...` and `test result: ok. 42 passed`, in a code block. Paste failures in full.
- **Terraform:** `terraform validate` and `tflint` results, and the `terraform plan` summary line,
  `Plan: N to add, N to change, N to destroy`, with the plan of what changed in a collapsed `<details>` block.
- **End-to-end on kind:** the kind and Kubernetes versions (`kind version`, `kubectl version`), the end-to-end test
  results, and `kubectl get pods,services -o wide` with the LoadBalancer addresses the tests reached.

Then what you could not run, and why, such as a test that needs `ANTHROPIC_API_KEY` when it is missing.

Keep secrets, tokens and kubeconfig contents out of it. When a run's output is long, keep it under
`/home/agent/code/.artifacts/<task>/`, outside the checkout, and attach it with `gh pr create --attach` or
`gh pr edit --attach`. A terminal recording, when the change is easier to follow moving, is made as the `recording`
skill describes.
