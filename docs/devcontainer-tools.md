## SlotMap Devcontainer Tooling

This document captures the contents of `.devcontainer/Dockerfile`, similar in spirit to the official Dev Containers C++ image reference. Use it as a checklist when updating dependencies or auditing what is available inside the remote workspace. The image now supports a compiler matrix (GCC 14/15 × Clang 21/22 plus clang-p2996); `docker-bake.hcl` tags reflect the chosen pair.

### Base Image and Users
| Item | Details |
| --- | --- |
| Base | `ubuntu:24.04` |
| Dev user | `USERNAME` build arg (defaults to a neutral user; typically set to the remote host user) with passwordless sudo |
| Shells | bash + zsh (Oh-My-Zsh not installed) |
| Timezone | `UTC` |

### Core Packages (APT)
Installed via `apt-get` in the first layer:
- Build chain: `build-essential`, LLVM toolchain from `apt.llvm.org` for the selected numeric `CLANG_VARIANT` (21 or 22; clang-p2996 is built from source only in the `*clangp2996` tags), `binutils`, GCC 14 from the Ubuntu Toolchain PPA (GCC 15 is built from source when enabled)
- Tooling: `curl`, `wget`, `sudo`, `pkg-config`, `bash-completion`, `zsh`, `graphviz`, `doxygen`, `rsync`, `python3` (+pip/venv), `tzdata`, `xz-utils`, `unzip`, `zip`, `tar`
- Debugging helpers: `debuginfod`, `debuginfod-client`
- vcpkg manifest prerequisites: `autoconf`, `automake`, `libtool`, `m4`, `autoconf-archive`, `patchelf`
- SSH / misc: `openssh-client`, `ca-certificates`, `gnupg`

### Additional Toolchain Components
| Tool | Version / Variant | Source |
| --- | --- | --- |
| Git | Latest stable via `ppa:git-core/ppa` |
| CMake | Latest from Kitware APT |
| GNU Make | 4.4.1 compiled from ftp.gnu.org |
| Ninja | v1.13.1 GitHub release (curl with retry) |
| Mold | v2.40.4 GitHub release (`mold` + `ld.mold`) |
| GitHub CLI | v2.83.1 GitHub release |
| GCC | GCC 14 from PPA; GCC 15.1.0 built from source under `/opt/gcc-15` when enabled (gcc15 permutations) |
| LLVM/Clang | Via `llvm.sh ${CLANG_VARIANT}` for 21/22 with extras (MLIR, BOLT, flang, libclc, libllvmlibc); clang-p2996 built from source under `/opt/clang-p2996` only in `*clangp2996` permutations |
| IWYU | `clang_${LLVM_VERSION}` branch built from source (matches LLVM variant); skipped when no numeric LLVM is installed (p2996 permutations) |
| MRDocs | v0.8.0 binary release |
| Mermaid CLI | Installed globally via npm |
| Node.js / npm | Official Node.js tarball v25.2.1 |
| jq | v1.8.1 GitHub release (`jq-linux-amd64`) |
| AWS CLI v2 | Latest Linux x86_64 zip installer |
| Linux perf | `linux-tools-common` + `linux-tools-generic` (+ best-effort `linux-tools-$(uname -r)`) |
| binutils + gdb | Built from source (`bminor/binutils-gdb` tag `binutils-2_45_1`) |
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
| `/home/<user>/workspace` | Default working directory (remote host bind mount) |
| `/var/cache/ccache` | Shared cache owned by the devcontainer user |
| `/var/cache/sccache` | Shared cache owned by the devcontainer user |
| `/opt/vcpkg` | vcpkg clone/tools |
| `/opt/vcpkg-downloads` | vcpkg download cache |
| `/opt/mrdocs` | MRDocs install |
| `/opt/llvm-packages-21.txt` | Snapshot of `apt-cache search 21` after enabling apt.llvm.org |
| `/opt/clang-p2996` | Bloomberg Clang P2996 installation root |

### Verification Commands
Run these inside the devcontainer to confirm key tools are available (adjust versions to the selected bake target):
```bash
clang++-21 --version     # or clang++-22 / clang++-p2996 (only in p2996 tags)
gcc-15 --version        # or gcc-14
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
flang-21 --version      # adjust to variant
clang-p2996 --version   # when using that variant
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

### Baking & Permutations
- The `docker-bake.hcl` defines the compiler matrix; bake args (`CLANG_VARIANT`, `ENABLE_CLANG_P2996`, `GCC_VERSION`, `MUTAGEN_VERSION`) must be passed explicitly. Example for the p2996/clang+GCC15 + Mutagen image:
  ```bash
  docker buildx bake \
    -f .devcontainer/docker-bake.hcl \
    devcontainer \
    --set base.tags=cpp-dev-base:local \
    --set devcontainer.tags=cpp-devcontainer:local \
    --set '*.args.BASE_IMAGE'=cpp-dev-base:local \
    --set '*.args.USERNAME'=${DEV_USER:-rmanaloto} --set '*.args.USER_UID'=1000 --set '*.args.USER_GID'=1000 \
    --set '*.args.CLANG_VARIANT'=p2996 \
    --set '*.args.ENABLE_CLANG_P2996'=1 \
    --set '*.args.GCC_VERSION'=15 \
    --set '*.args.MUTAGEN_VERSION'=v0.18.1
  ```
- `scripts/run_local_devcontainer.sh` currently bakes with the defaults from `docker-bake.hcl` (CLANG_VARIANT=21, ENABLE_CLANG_P2996=0, GCC_VERSION=15) unless you add `--set` overrides manually; if `DEVCONTAINER_SKIP_BAKE=1` in your env file, it reuses whatever image tag already exists.
- To ensure the running devcontainer matches a specific env permutation (e.g., `config/env/devcontainer.*clangp2996.env`), clear `DEVCONTAINER_SKIP_BAKE` and bake with the matching args before launching `devcontainer up`.

### Maintenance Notes
- If you update LLVM or GCC versions, also update IWYU branch and `update-alternatives` priorities.
- Pin vcpkg to a commit if reproducibility is required; currently the latest master is used.
- npm-installed Mermaid CLI provides diagram rendering for docs – ensure Node.js remains current for security fixes.
- The document draws inspiration from [devcontainers/images/src/cpp](https://github.com/devcontainers/images/tree/main/src/cpp); revisit periodically to stay aligned with upstream best practices.
- LLVM branch numbers (stable/qualification/development) can be refreshed via `.devcontainer/scripts/resolve_llvm_branches.sh`; export its output and pass `--set CLANG_QUAL=… --set CLANG_DEV=… --set CLANG_VARIANT=…` to `docker buildx bake` to avoid hard-coded versions. The helper `.devcontainer/scripts/build_remote_images.sh` wires this up for remote builds.
