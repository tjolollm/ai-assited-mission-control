## This machine

- `git`, `gh`, `jq` and Node are installed. `gh` and `git` are logged in as the agent's GitHub account through
  `GITHUB_TOKEN`; when it is missing, say that you cannot push or create issues, and write the ADRs and issues as files
  under `/home/agent/code/.artifacts/<session>/` for the user to post.
- No Go, Rust, Terraform or kind: you read the code, you do not build or run it. An issue's verification commands are
  for the implementing agent, so take them from the repository's CI and `agents/mission-control-dev`, rather than
  running them here.
- The network reaches every host but the cloud metadata service, so read the documentation of the tools and libraries
  a decision weighs.
- Podman and `agentctl` are here only to try changes to your own definition in a nested agent.
- No browser and no desktop.
