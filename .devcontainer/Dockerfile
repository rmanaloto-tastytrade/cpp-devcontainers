ARG UBUNTU_VERSION=24.04
ARG UBUNTU_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu-24.04
ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=${LOCAL_USER:-"devuser"}
ARG USER_UID=1000
ARG USER_GID=1000
ARG VCPKG_ROOT=/opt/vcpkg
ARG VCPKG_DOWNLOADS=/opt/vcpkg/downloads
ARG MRDOCS_VERSION=v0.8.0
ARG MRDOCS_ARCHIVE=MrDocs-0.8.0-Linux.tar.xz
ARG MRDOCS_DIR=MrDocs-0.8.0-Linux
ARG MRDOCS_SHA256=75f5b703e2230d7574eecc1640d16de668bd6aeb11713296e748d3378bb509f2
ARG NINJA_VERSION=1.13.1
ARG NINJA_SHA256=0830252db77884957a1a4b87b05a1e2d9b5f658b8367f82999a941884cbe0238
ARG MOLD_VERSION=2.40.4
ARG MOLD_ARCHIVE=mold-${MOLD_VERSION}-x86_64-linux.tar.gz
ARG MOLD_SHA256=4c999e19ffa31afa5aa429c679b665d5e2ca5a6b6832ad4b79668e8dcf3d8ec1
ARG GH_CLI_VERSION=2.83.1
ARG GH_CLI_SHA256=1c5252d4ce3db07b51c01ff0b909583da6364ff3fdc06d0c2e75e62dc0380a34
ARG CLANG_VARIANT=21  # used only in permutation stages
ARG LLVM_VERSION=${CLANG_VARIANT}
ARG IWYU_COMMIT=clang_${LLVM_VERSION}
ARG GCC_VERSION=14  # base stays generic; permutation stages override
ARG CCACHE_VERSION=4.12.1
ARG CCACHE_ARCHIVE=ccache-${CCACHE_VERSION}-linux-x86_64.tar.xz
ARG CCACHE_SHA256=742e6a6e17c0a060046874eece2949b221c228e1119698a4c6e0b096cbc87152
ARG SCCACHE_VERSION=0.12.0
ARG SCCACHE_ARCHIVE=sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz
ARG SCCACHE_SHA256=b0e89ead6899224a4ba2b90e9073bf1ce036d95bab30f3dc33c1e1468bc4ad44
ARG RIPGREP_VERSION=14.1.0
ARG RIPGREP_ARCHIVE=ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz
ARG RIPGREP_SHA256=f84757b07f425fe5cf11d87df6644691c644a5cd2348a2c670894272999d3ba7
ARG ZSTD_VERSION=1.5.7
ARG ZSTD_ARCHIVE=zstd-${ZSTD_VERSION}-linux-x86_64.tar.gz
ARG NODE_VERSION=25.2.1
ARG NODE_DIST=node-v${NODE_VERSION}-linux-x64
ARG NODE_SHA256=b9f6a97e81c89a9df45526b4f86dafdccaf12b82295f7bf35bdb2b0f5e68744f
ARG BINUTILS_GDB_TAG=binutils-2_45_1
ARG MAKE_VERSION=4.4.1
ARG MAKE_SHA256=dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
ARG CLANG_P2996_BRANCH=p2996
ARG CLANG_P2996_REPO=https://github.com/bloomberg/clang-p2996.git
ARG CLANG_P2996_PREFIX=/opt/clang-p2996
ARG JQ_VERSION=1.8.1
ARG JQ_SHA256=020468de7539ce70ef1bceaf7cde2e8c4f2ca6c3afb84642aabc5c97d9fc2a0d
ARG AWSCLI_VERSION=latest
ARG EGET_VERSION=v1.3.4
ARG MUTAGEN_VERSION=v0.18.1
ARG BASE_IMAGE=ghcr.io/rmanaloto-tastytrade/cpp-devcontainers/cpp-dev-base:local
ARG ENABLE_VALGRIND=1
ARG ENABLE_CPPCHECK=1
ARG ENABLE_IWYU=1
ARG ENABLE_CLANG_P2996=0
ARG ENABLE_GCC15=0
ARG GCC15_VERSION=15.1.0
ARG GCC15_JOBS=0
ARG CLANG_P2996_JOBS=0
ARG LLVM_APT_POCKET=
ARG VALGRIND_SHA256=c5c34a3380457b9b75606df890102e7df2c702b9420c2ebef9540f8b5d56264d

FROM ${UBUNTU_IMAGE} AS base

ARG DEBIAN_FRONTEND
ARG GCC_VERSION
ARG LLVM_VERSION
ARG CLANG_VARIANT
ARG BINUTILS_GDB_TAG
ARG MAKE_VERSION
ARG MAKE_SHA256
ARG NINJA_VERSION
ARG NINJA_SHA256
ARG LLVM_APT_POCKET
ARG CLANG_P2996_PREFIX
ARG ENABLE_GCC15
ARG ENABLE_CLANG_P2996
ARG ENABLE_IWYU
ARG EGET_VERSION
ARG MUTAGEN_VERSION

ENV LLVM_VERSION=${LLVM_VERSION} \
  TZ=UTC \
  VCPKG_FORCE_SYSTEM_BINARIES=1 \
  CCACHE_DIR=/var/cache/ccache \
  SCCACHE_DIR=/var/cache/sccache \
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Core OS packages, tooling, and dependencies required for building and docs
RUN --mount=type=cache,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt/lists \
  set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  wget \
  sudo \
  gnupg \
  software-properties-common \
  pkg-config \
  bash-completion \
  build-essential \
  unzip \
  zip \
  tar \
  python3 \
  python3-pip \
  python3-venv \
  rsync \
  tzdata \
  xz-utils \
  graphviz \
  doxygen \
  openssh-client \
  zsh \
  flex \
  bison \
  texinfo \
  libgmp-dev \
  libmpfr-dev \
  libmpc-dev \
  libexpat1-dev \
  zlib1g-dev \
  libzstd-dev \
  zstd \
  autoconf \
  automake \
  libtool \
  m4 \
  autoconf-archive \
  patchelf; \
  rm -rf /var/lib/apt/lists/*

# Linux perf tooling (kept in base so downstream stages share it)
RUN --mount=type=cache,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt/lists \
  set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends linux-tools-common linux-tools-generic; \
  KERNEL="$(uname -r)"; \
  apt-get install -y --no-install-recommends "linux-tools-${KERNEL}" || true; \
  rm -rf /var/lib/apt/lists/*

# Ubuntu toolchain PPA for latest GCC
RUN --mount=type=cache,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt/lists \
  set -eux; \
  add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
  apt-get update; \
  if apt-get install -y --no-install-recommends gcc-${GCC_VERSION} g++-${GCC_VERSION}; then \
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 20; \
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 20; \
  else \
  echo "gcc-${GCC_VERSION} not available from PPA; installing gcc-14 as fallback for builders" >&2; \
  apt-get install -y --no-install-recommends gcc-14 g++-14; \
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 10; \
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 10; \
  fi; \
  # keep any preinstalled toolchains; alternatives already prefer the requested version
  rm -rf /var/lib/apt/lists/*

# Latest Git via official PPA
RUN --mount=type=cache,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt/lists \
  set -eux; \
  add-apt-repository -y ppa:git-core/ppa; \
  apt-get update; \
  apt-get install -y --no-install-recommends git; \
  rm -rf /var/lib/apt/lists/*

# Kitware repository for latest CMake (needed for custom Clang builds)
RUN --mount=type=cache,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt/lists \
  set -eux; \
  curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/kitware-archive.gpg] https://apt.kitware.com/ubuntu/ noble main" > /etc/apt/sources.list.d/kitware.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends cmake; \
  rm -rf /var/lib/apt/lists/*

# Ninja (latest GitHub release with retries)
RUN set -eux; \
  curl -fSL --retry 5 --retry-delay 5 "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip" -o /tmp/ninja.zip; \
  echo "${NINJA_SHA256}  /tmp/ninja.zip" | sha256sum -c -; \
  unzip -d /tmp /tmp/ninja.zip; \
  install -m 0755 /tmp/ninja /usr/local/bin/ninja; \
  rm -rf /tmp/ninja /tmp/ninja.zip

# GNU Make (latest release)
RUN set -eux; \
  rm -f /tmp/make.tar.gz; \
  MAKE_URLS="https://mirrors.kernel.org/gnu/make/make-${MAKE_VERSION}.tar.gz \
  http://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz \
  https://ftpmirror.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz \
  https://github.com/mirror/make/releases/download/${MAKE_VERSION}/make-${MAKE_VERSION}.tar.gz"; \
  for url in ${MAKE_URLS}; do \
  if curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 90 "${url}" -o /tmp/make.tar.gz; then \
  break; \
  fi; \
  done; \
  [ -s /tmp/make.tar.gz ] || { echo "Make source download failed" >&2; exit 1; }; \
  if [ -n "${MAKE_SHA256:-}" ]; then echo "${MAKE_SHA256}  /tmp/make.tar.gz" | sha256sum -c -; fi; \
  tar -xzf /tmp/make.tar.gz -C /tmp; \
  cd /tmp/make-${MAKE_VERSION}; \
  ./configure --prefix=/usr/local; \
  make -j"$(nproc)"; \
  make install; \
  rm -rf /tmp/make.tar.gz /tmp/make-${MAKE_VERSION}

# (Permutation-specific LLVM/Clang installs happen in downstream stages.)

# binutils + gdb (latest release)
RUN set -eux; \
  curl -fsSL "https://github.com/bminor/binutils-gdb/archive/refs/tags/${BINUTILS_GDB_TAG}.tar.gz" -o /tmp/binutils-gdb.tar.gz; \
  mkdir -p /tmp/binutils-gdb; \
  tar -xzf /tmp/binutils-gdb.tar.gz -C /tmp/binutils-gdb --strip-components=1; \
  mkdir -p /tmp/binutils-gdb/build; \
  cd /tmp/binutils-gdb/build; \
  ../configure --disable-multilib --enable-gold --enable-plugins --with-system-zlib; \
  make -j"$(nproc)"; \
  make install; \
  rm -rf /tmp/binutils-gdb.tar.gz /tmp/binutils-gdb

# Ensure requested Clang toolchain exists for builder stages
RUN set -e; \
  if [ "${CLANG_VARIANT}" != "p2996" ]; then \
  if ! command -v "clang++-${CLANG_VARIANT}" >/dev/null 2>&1; then \
  OS_CODENAME="$(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME})"; \
  POCKET="${LLVM_APT_POCKET}"; \
  if [ -z "${POCKET}" ]; then \
  if [ "${CLANG_VARIANT}" = "22" ]; then \
  POCKET="llvm-toolchain-${OS_CODENAME}"; \
  else \
  POCKET="llvm-toolchain-${OS_CODENAME}-${CLANG_VARIANT}"; \
  fi; \
  fi; \
  echo "Using LLVM pocket ${POCKET} for clang-${CLANG_VARIANT} (base stage)"; \
  curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm-snapshot.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/${OS_CODENAME}/ ${POCKET} main" > /etc/apt/sources.list.d/llvm-${CLANG_VARIANT}.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  libllvm-${CLANG_VARIANT}-ocaml-dev libllvm${CLANG_VARIANT} \
  llvm-${CLANG_VARIANT} llvm-${CLANG_VARIANT}-dev llvm-${CLANG_VARIANT}-doc llvm-${CLANG_VARIANT}-examples llvm-${CLANG_VARIANT}-runtime \
  clang-${CLANG_VARIANT} clang-tools-${CLANG_VARIANT} clang-${CLANG_VARIANT}-doc libclang-common-${CLANG_VARIANT}-dev libclang-${CLANG_VARIANT}-dev libclang1-${CLANG_VARIANT} clang-format-${CLANG_VARIANT} python3-clang-${CLANG_VARIANT} clangd-${CLANG_VARIANT} clang-tidy-${CLANG_VARIANT} \
  libclang-rt-${CLANG_VARIANT}-dev \
  libpolly-${CLANG_VARIANT}-dev \
  libfuzzer-${CLANG_VARIANT}-dev \
  lldb-${CLANG_VARIANT} \
  lld-${CLANG_VARIANT} \
  libc++-${CLANG_VARIANT}-dev libc++abi-${CLANG_VARIANT}-dev \
  libomp-${CLANG_VARIANT}-dev \
  libclc-${CLANG_VARIANT}-dev \
  libunwind-${CLANG_VARIANT}-dev \
  libmlir-${CLANG_VARIANT}-dev mlir-${CLANG_VARIANT}-tools \
  libbolt-${CLANG_VARIANT}-dev bolt-${CLANG_VARIANT} \
  flang-${CLANG_VARIANT} \
  libclang-rt-${CLANG_VARIANT}-dev-wasm32 libclang-rt-${CLANG_VARIANT}-dev-wasm64 libc++-${CLANG_VARIANT}-dev-wasm32 libc++abi-${CLANG_VARIANT}-dev-wasm32 libclang-rt-${CLANG_VARIANT}-dev-wasm32 libclang-rt-${CLANG_VARIANT}-dev-wasm64 \
  libllvmlibc-${CLANG_VARIANT}-dev; \
  LC_ALL=C apt-cache search ${CLANG_VARIANT} | sort > /opt/llvm-packages-${CLANG_VARIANT}.txt; \
  rm -rf /var/lib/apt/lists/*; \
  fi; \
  fi


# ---------- Parallel builders (FROM base) ----------

FROM ${BASE_IMAGE} AS prebuilt_base

FROM prebuilt_base AS clang_p2996
ARG CLANG_P2996_BRANCH
ARG CLANG_P2996_REPO
ARG CLANG_P2996_PREFIX
ARG CLANG_P2996_JOBS
ARG ENABLE_CLANG_P2996
RUN --mount=type=cache,target=/tmp/clang-p2996-build \
  set -eux; \
  if [ "${ENABLE_CLANG_P2996}" != "1" ]; then \
  mkdir -p "/opt/stage${CLANG_P2996_PREFIX}" "${CLANG_P2996_PREFIX}"; \
  exit 0; \
  fi; \
  CLONE_DIR="/tmp/clang-p2996-src"; \
  BUILD_DIR="/tmp/clang-p2996-build"; \
  STAGE_PREFIX="/opt/stage${CLANG_P2996_PREFIX}"; \
  rm -rf "${CLONE_DIR}"; \
  git clone --depth=1 -b ${CLANG_P2996_BRANCH} ${CLANG_P2996_REPO} "${CLONE_DIR}"; \
  cmake -S "${CLONE_DIR}/llvm" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DCMAKE_INSTALL_PREFIX="${STAGE_PREFIX}" \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_BUILD_TESTS=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_OPTIMIZED_TABLEGEN=ON \
  -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=ON; \
  JOBS=${CLANG_P2996_JOBS:-0}; \
  if [ "$JOBS" -le 0 ]; then \
  JOBS=$(nproc); \
  JOBS=$((JOBS * 3 / 4)); \
  if [ "$JOBS" -lt 1 ]; then JOBS=1; fi; \
  fi; \
  cmake --build "${BUILD_DIR}" -j"${JOBS}"; \
  cmake --install "${BUILD_DIR}"; \
  ln -sf clang "${STAGE_PREFIX}/bin/clang-p2996"; \
  ln -sf clang++ "${STAGE_PREFIX}/bin/clang++-p2996"; \
  rm -rf "${CLONE_DIR}"

FROM prebuilt_base AS gcc15
ARG GCC15_VERSION
ARG GCC15_JOBS
ARG ENABLE_GCC15
RUN --mount=type=cache,target=/tmp/gcc15-build \
  set -eux; \
  if [ "${ENABLE_GCC15}" != "1" ]; then \
  mkdir -p /opt/gcc-15; \
  exit 0; \
  fi; \
  GCC_ARCHIVE="gcc-${GCC15_VERSION}.tar.xz"; \
  MIRRORS="https://ftp.gnu.org/gnu/gcc/gcc-${GCC15_VERSION} https://mirrors.kernel.org/gnu/gcc/gcc-${GCC15_VERSION}"; \
  fetch_with_mirror() { \
  local file="$1"; shift; \
  for m in "$@"; do \
  if curl -fsSL "${m}/${file}" -o "/tmp/${file}"; then return 0; fi; \
  done; \
  return 1; \
  }; \
  if ! fetch_with_mirror "${GCC_ARCHIVE}" ${MIRRORS}; then \
  echo "WARNING: failed to download ${GCC_ARCHIVE}; skipping gcc-15 build (will use PPA gcc if present)." >&2; \
  mkdir -p /opt/gcc-15; \
  exit 0; \
  fi; \
  tar -xJf /tmp/${GCC_ARCHIVE} -C /tmp; \
  PREREQS="gettext-0.22.tar.gz gmp-6.2.1.tar.bz2 mpfr-4.1.0.tar.bz2 mpc-1.2.1.tar.gz isl-0.24.tar.bz2"; \
  INF_MIRRORS="https://gcc.gnu.org/pub/gcc/infrastructure https://ftpmirror.gnu.org/pub/gcc/infrastructure"; \
  for p in $PREREQS; do \
  if [ ! -f "/tmp/gcc-${GCC15_VERSION}/${p}" ]; then \
  if fetch_with_mirror "$p" ${INF_MIRRORS}; then \
  mv "/tmp/${p}" "/tmp/gcc-${GCC15_VERSION}/" || true; \
  fi; \
  fi; \
  done; \
  cd /tmp/gcc-${GCC15_VERSION} || exit 1; \
  ./contrib/download_prerequisites || echo "WARNING: some prereqs may be missing; proceeding"; \
  mkdir -p /tmp/gcc15-build; \
  rm -rf /tmp/gcc15-build/*; \
  cd /tmp/gcc15-build; \
  ../gcc-${GCC15_VERSION}/configure --prefix=/opt/gcc-15 --program-suffix=-15 --disable-multilib --disable-bootstrap --enable-languages=c,c++; \
  JOBS=${GCC15_JOBS:-0}; \
  if [ "$JOBS" -le 0 ]; then \
  JOBS=$(nproc); \
  JOBS=$((JOBS * 3 / 4)); \
  if [ "$JOBS" -lt 1 ]; then JOBS=1; fi; \
  fi; \
  make -j"${JOBS}" || { echo "WARNING: gcc-15 build failed; leaving partial state"; exit 1; }; \
  make install || { echo "WARNING: gcc-15 install failed"; exit 1; }; \
  rm -rf /tmp/${GCC_ARCHIVE} /tmp/gcc-${GCC15_VERSION}

FROM prebuilt_base AS node_mermaid
ARG NODE_VERSION
ARG NODE_DIST
ARG NODE_SHA256
RUN --mount=type=cache,target=/root/.npm \
  set -eux; \
  STAGE_ROOT="/opt/stage"; \
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.xz" -o /tmp/node.tar.xz; \
  echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c -; \
  mkdir -p "${STAGE_ROOT}/usr/local/nodejs"; \
  tar -xJf /tmp/node.tar.xz -C "${STAGE_ROOT}/usr/local/nodejs"; \
  mkdir -p "${STAGE_ROOT}/usr/local/bin"; \
  ln -sf "../nodejs/${NODE_DIST}/bin/node" "${STAGE_ROOT}/usr/local/bin/node"; \
  ln -sf "../nodejs/${NODE_DIST}/bin/npm" "${STAGE_ROOT}/usr/local/bin/npm"; \
  ln -sf "../nodejs/${NODE_DIST}/bin/npx" "${STAGE_ROOT}/usr/local/bin/npx"; \
  PATH="${STAGE_ROOT}/usr/local/nodejs/${NODE_DIST}/bin:${PATH}" npm install -g @mermaid-js/mermaid-cli --prefix "${STAGE_ROOT}/usr/local"; \
  rm -rf /tmp/node.tar.xz

FROM prebuilt_base AS mold
ARG MOLD_VERSION
ARG MOLD_ARCHIVE
ARG MOLD_SHA256
RUN set -eux; \
  curl -fsSL "https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/${MOLD_ARCHIVE}" -o /tmp/mold.tar.gz; \
  echo "${MOLD_SHA256}  /tmp/mold.tar.gz" | sha256sum -c -; \
  mkdir -p /opt/stage/usr/local/bin; \
  tar -xzf /tmp/mold.tar.gz -C /tmp; \
  MOLD_DIR=/tmp/mold-${MOLD_VERSION}-x86_64-linux; \
  install -m 0755 ${MOLD_DIR}/bin/mold /opt/stage/usr/local/bin/mold; \
  install -m 0755 ${MOLD_DIR}/bin/ld.mold /opt/stage/usr/local/bin/ld.mold; \
  rm -rf /tmp/mold.tar.gz /tmp/mold-${MOLD_VERSION}-x86_64-linux

FROM prebuilt_base AS gh_cli
ARG GH_CLI_VERSION
ARG GH_CLI_SHA256
RUN set -eux; \
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_amd64.tar.gz" -o /tmp/gh.tar.gz; \
  echo "${GH_CLI_SHA256}  /tmp/gh.tar.gz" | sha256sum -c -; \
  tar -xzf /tmp/gh.tar.gz -C /tmp; \
  mkdir -p /opt/stage/usr/local/bin; \
  install -m 0755 /tmp/gh_${GH_CLI_VERSION}_linux_amd64/bin/gh /opt/stage/usr/local/bin/gh; \
  rm -rf /tmp/gh.tar.gz /tmp/gh_${GH_CLI_VERSION}_linux_amd64

FROM prebuilt_base AS ccache
ARG CCACHE_VERSION
ARG CCACHE_ARCHIVE
ARG CCACHE_SHA256
RUN set -eux; \
  curl -fsSL "https://github.com/ccache/ccache/releases/download/v${CCACHE_VERSION}/${CCACHE_ARCHIVE}" -o /tmp/ccache.tar.xz; \
  echo "${CCACHE_SHA256}  /tmp/ccache.tar.xz" | sha256sum -c -; \
  tar -xJf /tmp/ccache.tar.xz -C /tmp; \
  mkdir -p /opt/stage/usr/local/bin; \
  install -m 0755 /tmp/ccache-${CCACHE_VERSION}-linux-x86_64/ccache /opt/stage/usr/local/bin/ccache; \
  rm -rf /tmp/ccache.tar.xz /tmp/ccache-${CCACHE_VERSION}-linux-x86_64

FROM prebuilt_base AS sccache
ARG SCCACHE_VERSION
ARG SCCACHE_ARCHIVE
ARG SCCACHE_SHA256
RUN set -eux; \
  curl -fsSL "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/${SCCACHE_ARCHIVE}" -o /tmp/sccache.tar.gz; \
  echo "${SCCACHE_SHA256}  /tmp/sccache.tar.gz" | sha256sum -c -; \
  tar -xzf /tmp/sccache.tar.gz -C /tmp; \
  mkdir -p /opt/stage/usr/local/bin; \
  install -m 0755 /tmp/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl/sccache /opt/stage/usr/local/bin/sccache; \
  rm -rf /tmp/sccache.tar.gz /tmp/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl

FROM prebuilt_base AS ripgrep
ARG RIPGREP_VERSION
ARG RIPGREP_ARCHIVE
ARG RIPGREP_SHA256
RUN set -eux; \
  curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/${RIPGREP_ARCHIVE}" -o /tmp/rg.tar.gz; \
  echo "${RIPGREP_SHA256}  /tmp/rg.tar.gz" | sha256sum -c -; \
  tar -xzf /tmp/rg.tar.gz -C /tmp; \
  mkdir -p /opt/stage/usr/local/bin; \
  install -m 0755 /tmp/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/rg /opt/stage/usr/local/bin/rg; \
  rm -rf /tmp/rg.tar.gz /tmp/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl

FROM prebuilt_base AS cppcheck
ARG CPPCHECK_VERSION=2.13.0
RUN --mount=type=cache,target=/tmp/cppcheck-build \
  set -eux; \
  curl -fsSL "https://github.com/danmar/cppcheck/archive/refs/tags/${CPPCHECK_VERSION}.tar.gz" -o /tmp/cppcheck.tar.gz; \
  tar -xzf /tmp/cppcheck.tar.gz -C /tmp; \
  mkdir -p /tmp/cppcheck-build; \
  cmake -S /tmp/cppcheck-${CPPCHECK_VERSION} -B /tmp/cppcheck-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/stage/usr/local -DCMAKE_POLICY_VERSION=3.29 -DCMAKE_POLICY_VERSION_MINIMUM=3.5; \
  cmake --build /tmp/cppcheck-build -j"$(nproc)"; \
  cmake --install /tmp/cppcheck-build; \
  rm -rf /tmp/cppcheck.tar.gz /tmp/cppcheck-${CPPCHECK_VERSION}

FROM prebuilt_base AS valgrind
ARG VALGRIND_VERSION=3.23.0
ARG ENABLE_VALGRIND=1
ARG VALGRIND_SHA256
RUN --mount=type=cache,target=/tmp/valgrind-build \
  set -eux; \
  if [ "${ENABLE_VALGRIND}" != "1" ]; then \
  echo "Valgrind disabled"; \
  exit 0; \
  fi; \
  URLS="https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.tar.bz2 https://fossies.org/linux/misc/valgrind-${VALGRIND_VERSION}.tar.bz2"; \
  success=0; \
  for u in $URLS; do \
  if curl -fsSL "$u" -o /tmp/valgrind.tar.bz2; then success=1; break; fi; \
  done; \
  if [ "$success" -eq 0 ]; then \
  echo "Falling back to apt valgrind"; \
  apt-get update && apt-get install -y --no-install-recommends valgrind && rm -rf /var/lib/apt/lists/*; \
  mkdir -p /opt/stage/usr/local/bin; \
  if [ -x /usr/bin/valgrind ]; then cp /usr/bin/valgrind /opt/stage/usr/local/bin/valgrind; fi; \
  mkdir -p /opt/stage/usr/local/lib /opt/stage/usr/local/share; \
  exit 0; \
  fi; \
  echo "${VALGRIND_SHA256}  /tmp/valgrind.tar.bz2" | sha256sum -c -; \
  tar -xjf /tmp/valgrind.tar.bz2 -C /tmp; \
  cd /tmp/valgrind-${VALGRIND_VERSION}; \
  ./configure --prefix=/opt/stage/usr/local; \
  make -j"$(nproc)" || { cat config.log || true; exit 1; }; \
  make install; \
  rm -rf /tmp/valgrind.tar.bz2 /tmp/valgrind-${VALGRIND_VERSION}

FROM prebuilt_base AS python_tools
RUN set -eux; \
  mkdir -p /opt/stage/usr/local/bin; \
  curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/opt/stage/usr/local/bin sh;    curl -LsSf https://astral.sh/ruff/install.sh | RUFF_INSTALL_DIR=/opt/stage/usr/local/bin sh
# ty installation removed due to 404 (astral.sh/ty/install.sh)


FROM prebuilt_base AS pixi
RUN set -eux; \
  curl -fsSL https://pixi.sh/install.sh | bash -s -- -y; \
  mkdir -p /opt/stage/usr/local/bin; \
  mv /root/.pixi/bin/pixi /opt/stage/usr/local/bin/pixi; \
  rm -rf /root/.pixi

FROM prebuilt_base AS iwyu
ARG IWYU_COMMIT
ARG LLVM_VERSION
ARG ENABLE_IWYU
ARG IWYU_FALLBACK_COMMIT=clang_21
RUN set -eux; \
  if [ "${ENABLE_IWYU}" != "1" ]; then \
  mkdir -p /opt/stage/usr/local; \
  exit 0; \
  fi; \
  LLVM_VERSION_RESOLVED="${LLVM_VERSION:-${CLANG_VARIANT:-21}}"; \
  export LLVM_VERSION="${LLVM_VERSION_RESOLVED}"; \
  git clone https://github.com/include-what-you-use/include-what-you-use.git /tmp/iwyu; \
  cd /tmp/iwyu; \
  if ! git checkout "${IWYU_COMMIT}"; then \
  echo "IWYU commit ${IWYU_COMMIT} not found; falling back to ${IWYU_FALLBACK_COMMIT}" >&2; \
  git checkout "${IWYU_FALLBACK_COMMIT}"; \
  fi; \
  cmake -S . -B build -G Ninja -DIWYU_LLVM_ROOT_PATH=/usr/lib/llvm-${LLVM_VERSION_RESOLVED} -DCMAKE_INSTALL_PREFIX=/opt/stage/usr/local; \
  cmake --build build; \
  cmake --install build; \
  rm -rf /tmp/iwyu

FROM prebuilt_base AS mrdocs
ARG MRDOCS_VERSION
ARG MRDOCS_ARCHIVE
ARG MRDOCS_DIR
ARG MRDOCS_SHA256
RUN set -eux; \
  curl -fsSL "https://github.com/cppalliance/mrdocs/releases/download/${MRDOCS_VERSION}/${MRDOCS_ARCHIVE}" -o /tmp/mrdocs.tar.xz; \
  echo "${MRDOCS_SHA256}  /tmp/mrdocs.tar.xz" | sha256sum -c -; \
  mkdir -p /opt/stage/opt /opt/stage/usr/local/bin; \
  tar -xJf /tmp/mrdocs.tar.xz -C /opt/stage/opt; \
  mv /opt/stage/opt/${MRDOCS_DIR} /opt/stage/opt/mrdocs; \
  # keep mrdocs isolated under /opt/mrdocs (like vcpkg) and expose a convenience shim into /usr/local/bin\n\
  ln -s ../../opt/mrdocs/bin/mrdocs /opt/stage/usr/local/bin/mrdocs; \
  rm /tmp/mrdocs.tar.xz

FROM prebuilt_base AS jq
ARG JQ_VERSION
ARG JQ_SHA256
RUN set -eux; \
  mkdir -p /opt/stage/usr/local/bin; \
  curl -fsSL --retry 5 --retry-delay 3 "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" -o /opt/stage/usr/local/bin/jq; \
  echo "${JQ_SHA256}  /opt/stage/usr/local/bin/jq" | sha256sum -c -; \
  chmod 0755 /opt/stage/usr/local/bin/jq

FROM prebuilt_base AS awscli
ARG AWSCLI_VERSION
RUN set -eux; \
  mkdir -p /opt/stage/usr/local/bin; \
  if [ "${AWSCLI_VERSION}" = "latest" ]; then \
  AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; \
  else \
  AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip"; \
  fi; \
  curl -fsSL --retry 5 --retry-delay 3 "${AWS_URL}" -o /tmp/awscliv2.zip; \
  unzip -q /tmp/awscliv2.zip -d /tmp/awscliv2; \
  /tmp/awscliv2/aws/install --update --bin-dir /opt/stage/usr/local/bin --install-dir /opt/stage/aws-cli; \
  rm -rf /tmp/awscliv2.zip /tmp/awscliv2

# ---------- Merge tools ----------

FROM prebuilt_base AS tools_merge
ARG ENABLE_CLANG_P2996
ARG ENABLE_GCC15
RUN set -eux; mkdir -p /opt/clang-p2996 /opt/gcc-15
COPY --from=clang_p2996 /opt/stage/opt/clang-p2996/ /opt/clang-p2996/
COPY --from=gcc15 /opt/gcc-15/ /opt/gcc-15/
RUN set -eux; \
  if [ "${ENABLE_CLANG_P2996}" != "1" ]; then rm -rf /opt/clang-p2996; fi; \
  if [ "${ENABLE_GCC15}" != "1" ]; then rm -rf /opt/gcc-15; fi
COPY --from=node_mermaid /opt/stage/ /
COPY --from=mold /opt/stage/ /
COPY --from=gh_cli /opt/stage/ /
COPY --from=ccache /opt/stage/ /
COPY --from=sccache /opt/stage/ /
COPY --from=ripgrep /opt/stage/ /
COPY --from=cppcheck /opt/stage/ /
COPY --from=valgrind /opt/stage/ /
COPY --from=python_tools /opt/stage/ /
COPY --from=pixi /opt/stage/ /
COPY --from=iwyu /opt/stage/ /
COPY --from=mrdocs /opt/stage/ /
COPY --from=jq /opt/stage/ /
COPY --from=awscli /opt/stage/ /
# vcpkg is installed at runtime by projects; we just leave /opt/vcpkg empty for bind/caches

# ---------- final devcontainer ----------

FROM tools_merge AS devcontainer
ARG CLANG_VARIANT
ARG GCC_VERSION
ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG VCPKG_ROOT
ARG VCPKG_DOWNLOADS
ARG EGET_VERSION
ARG MUTAGEN_VERSION

ENV CMAKE_GENERATOR=Ninja \
  WORKSPACE_DIR="/home/${USERNAME}/workspace"

# Create non-root user for IDE/devcontainer usage
RUN if ! getent group ${USERNAME} >/dev/null; then \
  if getent group ${USER_GID} >/dev/null; then \
  groupadd --non-unique --gid ${USER_GID} ${USERNAME}; \
  else \
  groupadd --gid ${USER_GID} ${USERNAME}; \
  fi; \
  fi && \
  if ! id -u ${USERNAME} >/dev/null 2>&1; then \
  useradd --non-unique --uid ${USER_UID} --gid ${USERNAME} --shell /bin/bash --create-home ${USERNAME}; \
  fi && \
  usermod -aG sudo ${USERNAME} && \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${USERNAME} && \
  chmod 0440 /etc/sudoers.d/99-${USERNAME} && \
  chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
  chmod 0750 /home/${USERNAME} && \
  install -d -m 700 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.ssh

# Prepare shared directories for vcpkg, cmake, and caches
RUN mkdir -p /workspaces /var/cache/ccache /var/cache/sccache ${VCPKG_ROOT} ${VCPKG_DOWNLOADS} "${WORKSPACE_DIR}" && \
  chown -R ${USERNAME}:${USERNAME} /workspaces /var/cache/ccache /var/cache/sccache ${VCPKG_ROOT} ${VCPKG_DOWNLOADS} "${WORKSPACE_DIR}"

# eget (GitHub release fetcher) + mutagen (sync/forwarding)
RUN set -eux; \
  EGET_VER="${EGET_VERSION#v}"; \
  EGET_ASSET="eget-${EGET_VER}-linux_amd64.tar.gz"; \
  curl -fsSL "https://github.com/zyedidia/eget/releases/download/${EGET_VERSION}/${EGET_ASSET}" -o /tmp/eget.tar.gz; \
  tar -xzf /tmp/eget.tar.gz -C /tmp; \
  EGET_BIN="$(find /tmp -maxdepth 2 -type f -name 'eget' | head -n1)"; \
  install -m 0755 "${EGET_BIN}" /usr/local/bin/eget; \
  rm -rf /tmp/eget /tmp/eget.tar.gz /tmp/eget-*; \
  eget --version; \
  eget mutagen-io/mutagen \
  --tag "${MUTAGEN_VERSION}" \
  --asset "mutagen_linux_amd64_${MUTAGEN_VERSION}.tar.gz" \
  --download-only \
  --to /tmp/mutagen.tar.gz; \
  tar -xzf /tmp/mutagen.tar.gz -C /tmp; \
  MUT_BIN="$(find /tmp -maxdepth 2 -type f -name 'mutagen' | head -n1)"; \
  MUT_AGENTS_TAR="$(find /tmp -maxdepth 2 -type f -name 'mutagen-agents.tar.gz' | head -n1)"; \
  install -m 0755 "${MUT_BIN}" /usr/local/bin/mutagen; \
  install -d /usr/local/lib/mutagen; \
  install -m 0644 "${MUT_AGENTS_TAR}" /usr/local/lib/mutagen/mutagen-agents.tar.gz; \
  rm -rf /tmp/mutagen.tar.gz /tmp/mutagen*

# Ensure the requested Clang toolchain (and libc++) is present for numeric variants
RUN set -e; \
  if [ "${CLANG_VARIANT}" != "p2996" ]; then \
  if ! command -v "clang++-${CLANG_VARIANT}" >/dev/null 2>&1; then \
  OS_CODENAME="$(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME})"; \
  POCKET="${LLVM_APT_POCKET}"; \
  if [ -z "${POCKET}" ]; then \
  if [ "${CLANG_VARIANT}" = "22" ]; then \
  POCKET="llvm-toolchain-${OS_CODENAME}"; \
  else \
  POCKET="llvm-toolchain-${OS_CODENAME}-${CLANG_VARIANT}"; \
  fi; \
  fi; \
  echo "Using LLVM pocket ${POCKET} for clang-${CLANG_VARIANT}"; \
  curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm-snapshot.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/${OS_CODENAME}/ ${POCKET} main" > /etc/apt/sources.list.d/llvm-${CLANG_VARIANT}.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  libllvm-${CLANG_VARIANT}-ocaml-dev libllvm${CLANG_VARIANT} \
  llvm-${CLANG_VARIANT} llvm-${CLANG_VARIANT}-dev llvm-${CLANG_VARIANT}-doc llvm-${CLANG_VARIANT}-examples llvm-${CLANG_VARIANT}-runtime \
  clang-${CLANG_VARIANT} clang-tools-${CLANG_VARIANT} clang-${CLANG_VARIANT}-doc libclang-common-${CLANG_VARIANT}-dev libclang-${CLANG_VARIANT}-dev libclang1-${CLANG_VARIANT} clang-format-${CLANG_VARIANT} python3-clang-${CLANG_VARIANT} clangd-${CLANG_VARIANT} clang-tidy-${CLANG_VARIANT} \
  libclang-rt-${CLANG_VARIANT}-dev \
  libpolly-${CLANG_VARIANT}-dev \
  libfuzzer-${CLANG_VARIANT}-dev \
  lldb-${CLANG_VARIANT} \
  lld-${CLANG_VARIANT} \
  libc++-${CLANG_VARIANT}-dev libc++abi-${CLANG_VARIANT}-dev \
  libomp-${CLANG_VARIANT}-dev \
  libclc-${CLANG_VARIANT}-dev \
  libunwind-${CLANG_VARIANT}-dev \
  libmlir-${CLANG_VARIANT}-dev mlir-${CLANG_VARIANT}-tools \
  libbolt-${CLANG_VARIANT}-dev bolt-${CLANG_VARIANT} \
  flang-${CLANG_VARIANT} \
  libclang-rt-${CLANG_VARIANT}-dev-wasm32 libclang-rt-${CLANG_VARIANT}-dev-wasm64 libc++-${CLANG_VARIANT}-dev-wasm32 libc++abi-${CLANG_VARIANT}-dev-wasm32 libclang-rt-${CLANG_VARIANT}-dev-wasm32 libclang-rt-${CLANG_VARIANT}-dev-wasm64 \
  libllvmlibc-${CLANG_VARIANT}-dev; \
  LC_ALL=C apt-cache search ${CLANG_VARIANT} | sort > /opt/llvm-packages-${CLANG_VARIANT}.txt; \
  rm -rf /var/lib/apt/lists/*; \
  fi; \
  fi

# Ensure manually built toolchains are discoverable on PATH
RUN if [ -d /opt/gcc-15/bin ]; then \
  for b in gcc-15 g++-15 c++-15 x86_64-pc-linux-gnu-gcc-15 x86_64-pc-linux-gnu-g++-15; do \
  if [ -x "/opt/gcc-15/bin/${b}" ]; then ln -sf "/opt/gcc-15/bin/${b}" "/usr/local/bin/${b}"; fi; \
  done; \
  fi
RUN if [ -d /opt/clang-p2996/bin ]; then \
  for b in clang-p2996 clang++-p2996; do \
  if [ -x "/opt/clang-p2996/bin/${b}" ]; then ln -sf "/opt/clang-p2996/bin/${b}" "/usr/local/bin/${b}"; fi; \
  done; \
  fi

USER ${USERNAME}
WORKDIR /home/${USERNAME}/workspace

# ---------- Validation Stage ----------
# Runs functional checks against the assembled devcontainer image.
FROM devcontainer AS validate
ARG GCC_VERSION
ARG CLANG_VARIANT
ARG ENABLE_CLANG_P2996
ARG ENABLE_GCC15

RUN set -eux; \
  echo "--- core compiler sanity ---"; \
  echo 'int main(){return 0;}' > /tmp/test.cpp; \
  gcc --version | head -n 1; \
  g++ --version | head -n 1; \
  g++ -std=c++26 /tmp/test.cpp -o /tmp/test && /tmp/test; \
  if command -v clang++ >/dev/null 2>&1; then \
    clang++ --version | head -n 1; \
    clang++ -std=c++26 /tmp/test.cpp -o /tmp/test && /tmp/test; \
  fi; \
  if [ "${ENABLE_CLANG_P2996}" = "1" ] && [ -x /opt/clang-p2996/bin/clang++-p2996 ]; then \
    /opt/clang-p2996/bin/clang++-p2996 -v; \
    /opt/clang-p2996/bin/clang++-p2996 -std=c++26 -stdlib=libc++ /tmp/test.cpp -o /tmp/test && /tmp/test; \
  fi; \
  if [ "${ENABLE_GCC15}" = "1" ] && [ -x /opt/gcc-15/bin/g++-15 ]; then \
    /opt/gcc-15/bin/g++-15 --version | head -n 1; \
    /opt/gcc-15/bin/g++-15 -std=c++26 /tmp/test.cpp -o /tmp/test && /tmp/test; \
  fi; \
  rm -f /tmp/test /tmp/test.cpp; \
  echo "--- tools sanity ---"; \
  cmake --version; ninja --version; make --version; git --version; \
  mold --version; \
  gh --version; \
  ccache --version; \
  sccache --version; \
  rg --version; \
  jq --version; \
  node --version; npm --version; if command -v mmdc >/dev/null 2>&1; then mmdc --version; fi; \
  if command -v uv >/dev/null 2>&1; then uv --version; fi; \
  if command -v ruff >/dev/null 2>&1; then ruff --version; fi; \
  if command -v pixi >/dev/null 2>&1; then pixi --version; fi; \
  if command -v include-what-you-use >/dev/null 2>&1; then include-what-you-use --version; fi; \
  if command -v mrdocs >/dev/null 2>&1; then mrdocs --version; fi; \
  if command -v aws >/dev/null 2>&1; then aws --version; fi; \
  if command -v cppcheck >/dev/null 2>&1; then cppcheck --version; fi; \
  if command -v valgrind >/dev/null 2>&1; then valgrind --version; fi; \
  if command -v eget >/dev/null 2>&1; then eget --version; fi; \
  if command -v mutagen >/dev/null 2>&1; then mutagen version; fi; \
  echo "--- path / symlink checks ---"; \
  if [ -L /opt/vcpkg ]; then echo "vcpkg symlink: $(readlink -f /opt/vcpkg)"; else echo "ERROR: /opt/vcpkg not symlink"; exit 1; fi; \
  test -d /cppdev-cache || { echo "ERROR: /cppdev-cache missing"; exit 1; }; \
  if [ "${ENABLE_CLANG_P2996}" = "1" ]; then test -x /opt/clang-p2996/bin/clang++-p2996 || { echo "ERROR: clang-p2996 missing"; exit 1; }; fi; \
  if [ "${ENABLE_GCC15}" = "1" ]; then test -x /opt/gcc-15/bin/g++-15 || { echo "ERROR: gcc-15 missing"; exit 1; }; fi; \
  echo "--- validation complete ---"
