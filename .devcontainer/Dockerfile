FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y \
      build-essential \
      cmake \
      ninja-build \
      git \
      curl \
      g++ \
      clang \
      mold \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
