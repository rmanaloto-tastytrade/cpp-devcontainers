## SlotMap Devcontainer Tooling

This document captures the contents of `.devcontainer/Dockerfile`, similar in spirit to the official Dev Containers C++ image reference. Use it as a checklist when updating dependencies or auditing what is available inside the remote workspace.

### Base Image and Users
| Item | Details |
| --- | --- |
| Base | `ubuntu:24.04` |
| Dev user | `slotmap` (UID/GID configurable via build args) with passwordless sudo |
| Shells | bash + zsh (Oh-My-Zsh not installed) |
| Timezone | `UTC` |

### Core Packages (APT)
Installed via `apt-get` in the first layer:
- Build chain: `build-essential`, `clang-21` suite, `gcc-14` (from Ubuntu Toolchain PPA), `lld`, `lldb`, `llvm-21-dev`, `libclang-21-dev`, `libc++/libc++abi-21-dev`
- Tooling: `git`, `curl`, `wget`, `sudo`, `pkg-config`, `bash-completion`, `zsh`, `cppcheck`, `valgrind`, `gdb`, `nodejs`, `npm`, `graphviz`, `doxygen`, `rsync`, `python3` (+pip/venv), `tzdata`, `xz-utils`, `unzip`, `zip`, `tar`
- vcpkg manifest prerequisites: `autoconf`, `automake`, `libtool`, `m4`, `autoconf-archive`, `patchelf`
- SSH / misc: `openssh-client`, `ca-certificates`, `gnupg`

### Additional Toolchain Components
| Tool | Version | Source |
| --- | --- | --- |
| CMake | latest from Kitware APT |
| Ninja | v1.13.1 GitHub release (curl with retry) |
| Mold | v2.40.4 GitHub release (`mold` + `ld.mold`) |
| GitHub CLI | v2.83.1 GitHub release |
| IWYU | `clang_21` branch built from source (matches LLVM 21 install) |
| MRDocs | v0.8.0 binary release |
| Mermaid CLI | installed globally via npm |

### Caching & Productivity Tools
| Tool | Version | Notes |
| --- | --- | --- |
| ccache | v4.12.1 (binary tarball) |
| sccache | v0.12.0 (musl static binary) |
| ripgrep | v14.1.0 (musl static binary `rg`) |
| patchelf | 0.15.5 (Ubuntu package) | ensures vcpkg’s fixup steps don’t re-download |
| vcpkg | latest clone from GitHub with bootstrap script, download cache under `/opt/vcpkg-downloads`, bash/zsh integration |

Environment variables:
- `CCACHE_DIR=/var/cache/ccache`
- `SCCACHE_DIR=/var/cache/sccache`
- `VCPKG_ROOT=/opt/vcpkg`
- `VCPKG_DOWNLOADS=/opt/vcpkg-downloads`
- `VCPKG_FORCE_SYSTEM_BINARIES=1`

### Directory Layout
| Path | Description |
| --- | --- |
| `/workspaces/SlotMap` | Default working directory (mounted from host) |
| `/var/cache/ccache` | Shared cache owned by `slotmap` |
| `/var/cache/sccache` | Shared cache owned by `slotmap` |
| `/opt/vcpkg` | vcpkg clone/tools |
| `/opt/vcpkg-downloads` | vcpkg download cache |
| `/opt/mrdocs` | MRDocs install |

### Verification Commands
Run these inside the devcontainer to confirm key tools are available:
```bash
clang++-21 --version
gcc-14 --version
cmake --version
ninja --version
mold --version
include-what-you-use --version
ccache --version
sccache --version
rg --version
vcpkg version
```

### Maintenance Notes
- If you update LLVM or GCC versions, also update IWYU branch and `update-alternatives` priorities.
- Pin vcpkg to a commit if reproducibility is required; currently the latest master is used.
- npm-installed Mermaid CLI provides diagram rendering for docs – ensure Node.js remains current for security fixes.
- The document draws inspiration from [devcontainers/images/src/cpp](https://github.com/devcontainers/images/tree/main/src/cpp); revisit periodically to stay aligned with upstream best practices.
