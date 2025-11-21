## SlotMap Devcontainer Tooling

This document captures the contents of `.devcontainer/Dockerfile`, similar in spirit to the official Dev Containers C++ image reference. Use it as a checklist when updating dependencies or auditing what is available inside the remote workspace.

### Base Image and Users
| Item | Details |
| --- | --- |
| Base | `ubuntu:24.04` |
| Dev user | Matches remote host user (passed via build args; defaults to `vscode`) with passwordless sudo |
| Shells | bash + zsh (Oh-My-Zsh not installed) |
| Timezone | `UTC` |

### Core Packages (APT)
Installed via `apt-get` in the first layer:
- Build chain: `build-essential`, full LLVM 21 stack (clang/clangd/clang-tidy, lld, lldb, MLIR, BOLT, flang, libomp, libunwind, libclc, libfuzzer, polly, libllvmlibc, doc/examples packages), `gcc-14` (from Ubuntu Toolchain PPA), `binutils`
- Tooling: `curl`, `wget`, `sudo`, `pkg-config`, `bash-completion`, `zsh`, `cppcheck`, `valgrind`, `gdb`, `graphviz`, `doxygen`, `rsync`, `python3` (+pip/venv), `tzdata`, `xz-utils`, `unzip`, `zip`, `tar`
- vcpkg manifest prerequisites: `autoconf`, `automake`, `libtool`, `m4`, `autoconf-archive`, `patchelf`
- SSH / misc: `openssh-client`, `ca-certificates`, `gnupg`

### Additional Toolchain Components
| Tool | Version | Source |
| --- | --- | --- |
| Git | Latest stable via `ppa:git-core/ppa` |
| CMake | latest from Kitware APT |
| GNU Make | 4.4.1 compiled from ftp.gnu.org |
| Ninja | v1.13.1 GitHub release (curl with retry) |
| Mold | v2.40.4 GitHub release (`mold` + `ld.mold`) |
| GitHub CLI | v2.83.1 GitHub release |
| IWYU | `clang_21` branch built from source (matches LLVM 21 install) |
| MRDocs | v0.8.0 binary release |
| Mermaid CLI | installed globally via npm |
| Node.js / npm | Official Node.js tarball v25.2.1 |
| Linux perf | `linux-tools-common` + `linux-tools-generic` (+ best-effort `linux-tools-$(uname -r)`) |
| binutils + gdb | Built from source (`bminor/binutils-gdb` tag `binutils-2_45_1`) |
| LLVM extras | Installed via `llvm.sh ${LLVM_VERSION} all` plus additional packages (MLIR, BOLT, flang, libclc, libllvmlibc); package list logged to `/opt/llvm-packages-21.txt` |
| uv / ruff / ty | Astral install scripts (`/usr/local/bin`) |
| pixi | Official installer, binary moved to `/usr/local/bin` |

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
| `/var/cache/ccache` | Shared cache owned by the devcontainer user |
| `/var/cache/sccache` | Shared cache owned by the devcontainer user |
| `/opt/vcpkg` | vcpkg clone/tools |
| `/opt/vcpkg-downloads` | vcpkg download cache |
| `/opt/mrdocs` | MRDocs install |
| `/opt/llvm-packages-21.txt` | Snapshot of `apt-cache search 21` after enabling apt.llvm.org |

### Verification Commands
Run these inside the devcontainer to confirm key tools are available:
```bash
clang++-21 --version
gcc-14 --version
git --version
cmake --version
make --version
ninja --version
node --version
npm --version
mold --version
include-what-you-use --version
gdb --version
objdump --version
clangd --version
flang-21 --version
perf --version || perf --help
ccache --version
sccache --version
rg --version
uv --version
ruff --version
ty --version
pixi --version
vcpkg version
```

### Maintenance Notes
- If you update LLVM or GCC versions, also update IWYU branch and `update-alternatives` priorities.
- Pin vcpkg to a commit if reproducibility is required; currently the latest master is used.
- npm-installed Mermaid CLI provides diagram rendering for docs – ensure Node.js remains current for security fixes.
- The document draws inspiration from [devcontainers/images/src/cpp](https://github.com/devcontainers/images/tree/main/src/cpp); revisit periodically to stay aligned with upstream best practices.
