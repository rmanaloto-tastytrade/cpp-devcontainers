# Codex Review: Devcontainer Toolchain Isolation

Prompt (codex exec):
```
Review the following files for devcontainer/toolchain isolation; list issues and fixes only.
```

Key findings:
- Downloads via curl (ninja, binutils, mold, gh, ccache, sccache, ripgrep, jq, awscli, node, valgrind source, mrdocs) lack checksum/signature verification. Fix: pin versions and verify hashes/signatures.
- Apt/PPAs (ubuntu-toolchain-r, git-core, kitware, apt.llvm) are unpinned; installs “latest.” Fix: pin package versions, verify keys, consider snapshot/apt pinning.
- resolve_llvm_branches.sh scrapes apt.llvm.org at build time (non-deterministic, network-dependent). Fix: pin LLVM versions in config and update intentionally.
- post_create.sh clones/updates vcpkg from main with no pin/checksum. Fix: pin vcpkg commit/tag or vendor with checksum; avoid online updates in post_create.
- post_create.sh appends SSH config with `StrictHostKeyChecking accept-new` and installs authorized_keys from workspace without host-key validation. Fix: pre-seed known_hosts, enforce strict checking, and use only audited public keys.
- build_remote_images.sh uses buildx `--allow=fs="/System/Volumes/Data/home"` exposing host paths to remote builder. Fix: drop broad fs allows; restrict to dedicated cache path.
- devcontainer.json uses shared volume `cppdev-cache` for caches across projects. Fix: scope volume per workspace/project to avoid cross-project contamination.
