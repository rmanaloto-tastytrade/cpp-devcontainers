FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Base tooling
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        python3 \
        python3-pip \
        gnupg \
        lsb-release \
        unzip \
        bash \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI + Buildx
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

# Node/npm + devcontainers CLI
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @devcontainers/cli@0.80.2 \
    && rm -rf /var/lib/apt/lists/*

# Hadolint (pinned)
RUN curl -fsSLo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 \
    && echo "56de6d5e5ec427e17b74fa48d51271c7fc0d61244bf5c90e828aab8362d55010  /usr/local/bin/hadolint" | sha256sum -c - \
    && chmod +x /usr/local/bin/hadolint

WORKDIR /workspace
