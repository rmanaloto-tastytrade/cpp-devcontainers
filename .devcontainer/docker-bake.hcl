variable "TAG" {
  default = "devcontainer:local"
}

variable "BASE_TAG" {
  default = "dev-base:local"
}

variable "PLATFORM" {
  default = "linux/amd64"
}

target "_base" {
  context    = "."
  dockerfile = ".devcontainer/Dockerfile"
  platform   = [variable.PLATFORM]
  cache-from = ["type=local,src=.docker/cache"]
  cache-to   = ["type=local,dest=.docker/cache,mode=max"]
  args = {
    UBUNTU_VERSION  = "24.04"
    USERNAME        = "slotmap"
    USER_UID        = "1000"
    USER_GID        = "1000"
    BASE_IMAGE      = "${BASE_TAG}"
    VCPKG_ROOT      = "/opt/vcpkg"
    VCPKG_DOWNLOADS = "/opt/vcpkg/downloads"
    MRDOCS_VERSION  = "v0.8.0"
    MRDOCS_ARCHIVE  = "MrDocs-0.8.0-Linux.tar.xz"
    MRDOCS_DIR      = "MrDocs-0.8.0-Linux"
    NINJA_VERSION   = "1.13.1"
    MOLD_VERSION    = "2.40.4"
    MOLD_ARCHIVE    = "mold-2.40.4-x86_64-linux.tar.gz"
    GH_CLI_VERSION  = "2.83.1"
    LLVM_VERSION    = "21"
    IWYU_COMMIT     = "clang_21"
    GCC_VERSION     = "14"
    CCACHE_VERSION  = "4.12.1"
    CCACHE_ARCHIVE  = "ccache-4.12.1-linux-x86_64.tar.xz"
    SCCACHE_VERSION = "0.12.0"
    SCCACHE_ARCHIVE = "sccache-v0.12.0-x86_64-unknown-linux-musl.tar.gz"
    RIPGREP_VERSION = "14.1.0"
    RIPGREP_ARCHIVE = "ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz"
    NODE_VERSION    = "25.2.1"
    NODE_DIST       = "node-v25.2.1-linux-x64"
    BINUTILS_GDB_TAG = "binutils-2_45_1"
    MAKE_VERSION     = "4.4.1"
    CLANG_P2996_BRANCH = "p2996"
    CLANG_P2996_REPO   = "https://github.com/bloomberg/clang-p2996.git"
    CLANG_P2996_PREFIX = "/opt/clang-p2996"
  }
}

target "base" {
  inherits = ["_base"]
  target   = "base"
  tags     = [variable.BASE_TAG]
}

target "clang_p2996" { inherits = ["_base"]; target = "clang_p2996"; dependsOn = ["base"] }
target "node_mermaid" { inherits = ["_base"]; target = "node_mermaid"; dependsOn = ["base"] }
target "mold" { inherits = ["_base"]; target = "mold"; dependsOn = ["base"] }
target "gh_cli" { inherits = ["_base"]; target = "gh_cli"; dependsOn = ["base"] }
target "ccache" { inherits = ["_base"]; target = "ccache"; dependsOn = ["base"] }
target "sccache" { inherits = ["_base"]; target = "sccache"; dependsOn = ["base"] }
target "ripgrep" { inherits = ["_base"]; target = "ripgrep"; dependsOn = ["base"] }
target "cppcheck" { inherits = ["_base"]; target = "cppcheck"; dependsOn = ["base"] }
target "valgrind" { inherits = ["_base"]; target = "valgrind"; dependsOn = ["base"] }
target "python_tools" { inherits = ["_base"]; target = "python_tools"; dependsOn = ["base"] }
target "pixi" { inherits = ["_base"]; target = "pixi"; dependsOn = ["base"] }
target "iwyu" { inherits = ["_base"]; target = "iwyu"; dependsOn = ["base"] }
target "mrdocs" { inherits = ["_base"]; target = "mrdocs"; dependsOn = ["base"] }

group "tools" {
  targets = [
    "clang_p2996",
    "node_mermaid",
    "mold",
    "gh_cli",
    "ccache",
    "sccache",
    "ripgrep",
    "cppcheck",
    "valgrind",
    "python_tools",
    "pixi",
    "iwyu",
    "mrdocs",
  ]
}

target "tools_merge" {
  inherits  = ["_base"]
  target    = "tools_merge"
  dependsOn = ["tools"]
}

target "devcontainer" {
  inherits  = ["_base"]
  target    = "devcontainer"
  dependsOn = ["tools_merge"]
  tags      = [variable.TAG]
  labels = {
    "org.opencontainers.image.title"       = "Devcontainer"
    "org.opencontainers.image.description" = "Generic C++ tooling devcontainer image"
    "org.opencontainers.image.source"      = "local"
  }
}

group "default" {
  targets = ["devcontainer"]
}
