# The image of the Mission Control architect agent, built on the agentctl base image of release v0.1.0-preview.15.
# The agent grills, writes ADRs and creates issues with git and gh, which the base has, so the image adds only Podman
# and agentctl, to try changes to its own definition in a nested agent, and the repository to clone at boot.
FROM ghcr.io/digdir/agentctl-base:ubuntu-26.04-v0.1.0-preview.15@sha256:dd96a8413e1890b58ae4cde092bfc8b97fcb9e221822fdcb8bb3dc26466be949 AS minimal

# The base ends as the unprivileged agent user; installing features needs root again.
USER root

# Podman, on which a nested agentd runs and builds agent images.
RUN agent-feature install containers

# agentctl and agentd of the same release as the base, to try changes to this agent's definition in a nested agent.
COPY --from=ghcr.io/digdir/agentctl:v0.1.0-preview.15@sha256:1bc767955b6740c4b65e402332e8099154a0da8a4a80ae8f778182647dcdf40e \
    /agentctl /agentd /usr/local/bin/

# The repositories to clone into /home/agent/code at boot.
COPY common/workspace.list /etc/agent-workspace.d/mission-control.list

# The checks run with a HOME of their own, since gh writes its state to it, and root's would lock the agent out of
# /home/agent.
RUN export HOME="$(mktemp -d)" \
    && gh --version \
    && agentctl --version \
    && rm -rf "${HOME}" \
    && agent-image-check

USER agent
