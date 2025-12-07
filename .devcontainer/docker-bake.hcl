variable "TAG" {
  default = "cpp-cpp-devcontainer:local"
}

variable "BASE_TAG" {
  default = "cpp-cpp-dev-base:local"
}

variable "PLATFORM" {
  default = "linux/amd64"
}

variable "CLANG_VARIANT" {
  default = "21"
}

variable "CLANG_QUAL" {
  # Qualification branch (defaults to 21; override via --set CLANG_QUAL=xx)
  default = "21"
}

variable "CLANG_DEV" {
  # Development branch (defaults to 22; override via --set CLANG_DEV=xx)
  default = "22"
}

variable "GCC_VERSION" {
  default = "14"
}

variable "ENABLE_CLANG_P2996" {
  default = "0"
}

variable "ENABLE_GCC15" {
  default = "0"
}

variable "EGET_VERSION" {
  default = "v1.3.4"
}

variable "MUTAGEN_VERSION" {
  default = "v0.18.1"
}

variable "ZSTD_VERSION" {
  default = "1.5.7"
}

variable "ZSTD_ARCHIVE" {
  default = "zstd-v1.5.7-linux.tar.gz"
}

target "_base" {
  context    = "."
  dockerfile = ".devcontainer/Dockerfile"
  platform   = [variable.PLATFORM]
  args = {
    UBUNTU_VERSION     = "24.04"
    USERNAME           = "slotmap"
    USER_UID           = "1000"
    USER_GID           = "1000"
    BASE_IMAGE         = "${BASE_TAG}"
    VCPKG_ROOT         = "/opt/vcpkg"
    VCPKG_DOWNLOADS    = "/opt/vcpkg/downloads"
    MRDOCS_VERSION     = "v0.8.0"
    MRDOCS_ARCHIVE     = "MrDocs-0.8.0-Linux.tar.xz"
    MRDOCS_DIR         = "MrDocs-0.8.0-Linux"
    NINJA_VERSION      = "1.13.1"
    MOLD_VERSION       = "2.40.4"
    MOLD_ARCHIVE       = "mold-2.40.4-x86_64-linux.tar.gz"
    GH_CLI_VERSION     = "2.83.1"
    CLANG_VARIANT      = "${CLANG_VARIANT}"
    IWYU_COMMIT        = "clang_${CLANG_VARIANT}"
    GCC_VERSION        = "${GCC_VERSION}"
    CCACHE_VERSION     = "4.12.1"
    CCACHE_ARCHIVE     = "ccache-4.12.1-linux-x86_64.tar.xz"
    SCCACHE_VERSION    = "0.12.0"
    SCCACHE_ARCHIVE    = "sccache-v0.12.0-x86_64-unknown-linux-musl.tar.gz"
    RIPGREP_VERSION    = "14.1.0"
    RIPGREP_ARCHIVE    = "ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz"
    ZSTD_VERSION       = "${ZSTD_VERSION}"
    ZSTD_ARCHIVE       = "${ZSTD_ARCHIVE}"
    NODE_VERSION       = "25.2.1"
    NODE_DIST          = "node-v25.2.1-linux-x64"
    BINUTILS_GDB_TAG   = "binutils-2_45_1"
    MAKE_VERSION       = "4.4.1"
    CLANG_P2996_BRANCH = "p2996"
    CLANG_P2996_REPO   = "https://github.com/bloomberg/clang-p2996.git"
    CLANG_P2996_PREFIX = "/opt/clang-p2996"
    CLANG_P2996_JOBS   = "0"
    LLVM_APT_POCKET    = ""
    ENABLE_CLANG_P2996 = "0"
    ENABLE_GCC15       = "0"
    ENABLE_IWYU        = "1"
    JQ_VERSION         = "1.8.1"
    AWSCLI_VERSION     = "latest"
    GCC15_VERSION      = "15.1.0"
    GCC15_JOBS         = "0"
    EGET_VERSION       = "${EGET_VERSION}"
    MUTAGEN_VERSION    = "${MUTAGEN_VERSION}"
  }
}

target "base" {
  inherits = ["_base"]
  target   = "base"
  tags     = ["${BASE_TAG}"]
}

target "clang_p2996" {
  inherits  = ["_base"]
  target    = "clang_p2996"
  dependsOn = ["base"]
}

target "node_mermaid" {
  inherits  = ["_base"]
  target    = "node_mermaid"
  dependsOn = ["base"]
}

target "mold" {
  inherits  = ["_base"]
  target    = "mold"
  dependsOn = ["base"]
}

target "gh_cli" {
  inherits  = ["_base"]
  target    = "gh_cli"
  dependsOn = ["base"]
}

target "gcc15" {
  inherits  = ["_base"]
  target    = "gcc15"
  dependsOn = ["base"]
}

target "ccache" {
  inherits  = ["_base"]
  target    = "ccache"
  dependsOn = ["base"]
}

target "sccache" {
  inherits  = ["_base"]
  target    = "sccache"
  dependsOn = ["base"]
}

target "ripgrep" {
  inherits  = ["_base"]
  target    = "ripgrep"
  dependsOn = ["base"]
}

target "cppcheck" {
  inherits  = ["_base"]
  target    = "cppcheck"
  dependsOn = ["base"]
}

target "valgrind" {
  inherits  = ["_base"]
  target    = "valgrind"
  dependsOn = ["base"]
}

target "python_tools" {
  inherits  = ["_base"]
  target    = "python_tools"
  dependsOn = ["base"]
}

target "pixi" {
  inherits  = ["_base"]
  target    = "pixi"
  dependsOn = ["base"]
}

target "iwyu" {
  inherits  = ["_base"]
  target    = "iwyu"
  dependsOn = ["base"]
}

target "mrdocs" {
  inherits  = ["_base"]
  target    = "mrdocs"
  dependsOn = ["base"]
}

target "jq" {
  inherits  = ["_base"]
  target    = "jq"
  dependsOn = ["base"]
}

target "awscli" {
  inherits  = ["_base"]
  target    = "awscli"
  dependsOn = ["base"]
}

group "tools" {
  targets = [
    "clang_p2996",
    "node_mermaid",
    "mold",
    "gh_cli",
    "gcc15",
    "ccache",
    "sccache",
    "ripgrep",
    "cppcheck",
    "valgrind",
    "python_tools",
    "pixi",
    "iwyu",
    "mrdocs",
    "jq",
    "awscli",
  ]
}

target "tools_merge" {
  inherits  = ["_base"]
  target    = "tools_merge"
  dependsOn = ["tools"]
  args = {
    ENABLE_CLANG_P2996 = "${ENABLE_CLANG_P2996}"
    ENABLE_GCC15       = "${ENABLE_GCC15}"
  }
}

target "devcontainer" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["${TAG}"]
  labels = {
    "org.opencontainers.image.title"       = "Devcontainer"
    "org.opencontainers.image.description" = "Generic C++ tooling devcontainer image"
    "org.opencontainers.image.source"      = "local"
  }
}

group "default" {
  targets = ["devcontainer"]
}

# Explicit compiler permutations (gcc/clang)
target "devcontainer_gcc14_clang_qual" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["cpp-cpp-devcontainer:gcc14-clang${CLANG_QUAL}"]
  args = {
    GCC_VERSION        = "14"
    CLANG_VARIANT      = "${CLANG_QUAL}"
    ENABLE_GCC15       = "0"
    ENABLE_CLANG_P2996 = "0"
    ENABLE_IWYU        = "1"
  }
}

target "devcontainer_gcc14_clang_dev" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["cpp-cpp-devcontainer:gcc14-clang${CLANG_DEV}"]
  args = {
    GCC_VERSION        = "14"
    CLANG_VARIANT      = "${CLANG_DEV}"
    ENABLE_GCC15       = "0"
    ENABLE_CLANG_P2996 = "0"
    ENABLE_IWYU        = "1"
  }
}

target "devcontainer_gcc14_clangp2996" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["cpp-cpp-devcontainer:gcc14-clangp2996"]
  args = {
    GCC_VERSION        = "14"
    CLANG_VARIANT      = "p2996"
    ENABLE_GCC15       = "0"
    ENABLE_CLANG_P2996 = "1"
    ENABLE_IWYU        = "0"
  }
}

target "devcontainer_gcc15_clang_qual" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["cpp-cpp-devcontainer:gcc15-clang${CLANG_QUAL}"]
  args = {
    GCC_VERSION        = "15"
    CLANG_VARIANT      = "${CLANG_QUAL}"
    ENABLE_GCC15       = "1"
    ENABLE_CLANG_P2996 = "0"
    ENABLE_IWYU        = "1"
  }
}

target "devcontainer_gcc15_clang_dev" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["cpp-cpp-devcontainer:gcc15-clang${CLANG_DEV}"]
  args = {
    GCC_VERSION        = "15"
    CLANG_VARIANT      = "${CLANG_DEV}"
    ENABLE_GCC15       = "1"
    ENABLE_CLANG_P2996 = "0"
    ENABLE_IWYU        = "1"
  }
}

target "devcontainer_gcc15_clangp2996" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = ["cpp-cpp-devcontainer:gcc15-clangp2996"]
  args = {
    GCC_VERSION        = "15"
    CLANG_VARIANT      = "p2996"
    ENABLE_GCC15       = "1"
    ENABLE_CLANG_P2996 = "1"
    ENABLE_IWYU        = "0"
  }
}

group "matrix" {
  targets = [
    "devcontainer_gcc14_clang_qual",
    "devcontainer_gcc14_clang_dev",
    "devcontainer_gcc14_clangp2996",
    "devcontainer_gcc15_clang_qual",
    "devcontainer_gcc15_clang_dev",
    "devcontainer_gcc15_clangp2996",
  ]
}

# Validation targets (cache-only) exercising the validate stage for each permutation.
target "validate_gcc14_clang_qual" {
  inherits = ["devcontainer_gcc14_clang_qual"]
  target   = "validate"
  output   = ["type=cacheonly"]
}

target "validate_gcc14_clang_dev" {
  inherits = ["devcontainer_gcc14_clang_dev"]
  target   = "validate"
  output   = ["type=cacheonly"]
}

target "validate_gcc14_clangp2996" {
  inherits = ["devcontainer_gcc14_clangp2996"]
  target   = "validate"
  output   = ["type=cacheonly"]
}

target "validate_gcc15_clang_qual" {
  inherits = ["devcontainer_gcc15_clang_qual"]
  target   = "validate"
  output   = ["type=cacheonly"]
}

target "validate_gcc15_clang_dev" {
  inherits = ["devcontainer_gcc15_clang_dev"]
  target   = "validate"
  output   = ["type=cacheonly"]
}

target "validate_gcc15_clangp2996" {
  inherits = ["devcontainer_gcc15_clangp2996"]
  target   = "validate"
  output   = ["type=cacheonly"]
}

group "validate" {
  targets = [
    "validate_gcc14_clang_qual",
    "validate_gcc14_clang_dev",
    "validate_gcc14_clangp2996",
    "validate_gcc15_clang_qual",
    "validate_gcc15_clang_dev",
    "validate_gcc15_clangp2996",
  ]
}
