#!/usr/bin/env bash

# Helper to resolve a Clang branch name into a numeric variant and apt pocket.
# Usage: source this file, then call resolve_clang_branch
#
# Inputs (env vars, optional):
#   CLANG_BRANCH: stable | qualification | development | <number> (e.g., 21, 22)
#   CLANG_VARIANT: optional override; if set, takes precedence over branch
#   UBUNTU_CODENAME: optional codename for apt pocket (default: noble)
#
# Outputs (exported):
#   CLANG_VARIANT: numeric or "p2996" if explicitly set
#   LLVM_APT_POCKET: apt pocket name to fetch llvm/clang from
resolve_clang_branch() {
  local branch="${CLANG_BRANCH:-}"
  local variant="${CLANG_VARIANT:-}"
  local codename="${UBUNTU_CODENAME:-noble}"

  if [[ -z "$variant" ]]; then
    case "${branch}" in
      stable) variant="20" ;;
      qualification) variant="21" ;;
      development) variant="22" ;;
      "" ) variant="" ;; # leave unset; caller may set elsewhere
      *) variant="${branch}" ;;
    esac
  fi

  # Derive pocket: dev (22) uses unversioned pocket; numeric uses -<version>
  local pocket=""
  if [[ -n "$variant" && "$variant" != "p2996" ]]; then
    if [[ "$variant" == "22" ]]; then
      pocket="llvm-toolchain-${codename}"
    else
      pocket="llvm-toolchain-${codename}-${variant}"
    fi
  fi

  export CLANG_VARIANT="${variant}"
  export LLVM_APT_POCKET="${pocket}"
}
