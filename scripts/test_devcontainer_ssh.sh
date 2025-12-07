#!/usr/bin/env bash
set -euo pipefail

# Optional local env overrides
CONFIG_ENV_FILE=${CONFIG_ENV_FILE:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/env/devcontainer.env"}
if [[ -f "$CONFIG_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_ENV_FILE"
fi

# Verbose SSH connectivity test to the devcontainer exposed on a remote host.
# Supply host/user/port explicitly (no baked-in host/user); defaults are neutral.

usage() {
  cat <<'USAGE'
Usage: scripts/test_devcontainer_ssh.sh [options]

Options:
  --host <hostname>        Remote host (required unless DEVCONTAINER_REMOTE_HOST set)
  --port <port>            Remote SSH port (default: DEVCONTAINER_SSH_PORT or 9222)
  --user <username>        SSH username (required unless DEVCONTAINER_REMOTE_USER set)
  --key <path>             Private key path (default: ~/.ssh/id_ed25519)
  --known-hosts <path>     Known hosts file (default: ~/.ssh/known_hosts)
  --clear-known-host       Remove existing host key entry for [host]:[port] before testing
  --auto-accept            Skip host key prompts (clears known_hosts entry first)
  --clang-variant <ver>    Expected clang variant (e.g., 21, 22, p2996)
  --gcc-version <ver>      Expected gcc version (e.g., 14, 15)
  --jump-user <user>       SSH user for proxy jump to the host (default: --user)
  --no-proxyjump           Disable ProxyJump and connect directly (requires host port exposed beyond localhost)
  -h, --help               Show this help
USAGE
}

HOST="${DEVCONTAINER_REMOTE_HOST:-}"
PORT="${DEVCONTAINER_SSH_PORT:-9222}"
USER_NAME="${DEVCONTAINER_REMOTE_USER:-}"
KEY_PATH="$HOME/.ssh/id_ed25519"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
CLEAR_KNOWN_HOST=0
AUTO_ACCEPT=0
USE_PROXYJUMP=1
JUMP_USER=""
EXPECT_CLANG=""
EXPECT_GCC=""
CXX_STD="${DEVCONTAINER_CXX_STD:-c++26}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --key) KEY_PATH="$2"; shift 2 ;;
    --known-hosts) KNOWN_HOSTS_FILE="$2"; shift 2 ;;
    --clear-known-host) CLEAR_KNOWN_HOST=1; shift ;;
    --auto-accept) AUTO_ACCEPT=1; CLEAR_KNOWN_HOST=1; shift ;;
    --clang-variant) EXPECT_CLANG="$2"; shift 2 ;;
    --gcc-version) EXPECT_GCC="$2"; shift 2 ;;
    --cxx-std) CXX_STD="$2"; shift 2 ;;
    --jump-user) JUMP_USER="$2"; shift 2 ;;
    --no-proxyjump) USE_PROXYJUMP=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$AUTO_ACCEPT" == "1" ]]; then
  echo "[ssh-test] Auto-accept enabled; host key will be accepted without prompt."
fi

[[ -n "$HOST" ]] || { echo "[ssh-test] ERROR: host is required (pass --host or set DEVCONTAINER_REMOTE_HOST)"; exit 1; }
[[ -n "$USER_NAME" ]] || { echo "[ssh-test] ERROR: user is required (pass --user or set DEVCONTAINER_REMOTE_USER)"; exit 1; }
[[ -f "$KEY_PATH" ]] || { echo "[ssh-test] ERROR: key not found: $KEY_PATH" >&2; exit 1; }

echo "[ssh-test] Host: $HOST"
echo "[ssh-test] Port: $PORT"
echo "[ssh-test] User: $USER_NAME"
[[ -n "$JUMP_USER" ]] && echo "[ssh-test] Jump user: $JUMP_USER"
echo "[ssh-test] Key : $KEY_PATH"
echo "[ssh-test] Known hosts file: $KNOWN_HOSTS_FILE"

echo "[ssh-test] Key fingerprint:"
ssh-keygen -lf "$KEY_PATH" || true

if [[ "$CLEAR_KNOWN_HOST" -eq 1 ]]; then
  echo "[ssh-test] Clearing existing host key for [$HOST]:$PORT from $KNOWN_HOSTS_FILE"
  CANON_HOST=$(ssh -G "$HOST" 2>/dev/null | awk '/^hostname / {print $2}' | head -n1)
  [[ -z "$CANON_HOST" ]] && CANON_HOST="$HOST"
  ssh-keygen -R "[$HOST]:$PORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
  ssh-keygen -R "[$CANON_HOST]:$PORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
fi

TARGET_HOST="$HOST"
PROXY_OPTS=()
if [[ "$USE_PROXYJUMP" -eq 1 ]]; then
  PROXY_USER="${JUMP_USER:-$USER_NAME}"
  PROXY_OPTS=(-J "${PROXY_USER}@${HOST}")
  TARGET_HOST="127.0.0.1"
fi

# Proactively clear stale container host key to avoid mismatch errors when the
# devcontainer is rebuilt (host key changes frequently).
HOSTPORT="[$TARGET_HOST]:$PORT"
if ssh-keygen -F "$HOSTPORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1; then
  echo "[ssh-test] Removing stale host key for $HOSTPORT from $KNOWN_HOSTS_FILE"
  ssh-keygen -R "$HOSTPORT" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
fi

SSH_CMD=(ssh -vvv
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o UserKnownHostsFile="$KNOWN_HOSTS_FILE"
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=10
  "${PROXY_OPTS[@]}"
  -p "$PORT"
  "${USER_NAME}@${TARGET_HOST}"
  "echo SSH_OK")

echo "[ssh-test] Executing: ${SSH_CMD[*]}"
if "${SSH_CMD[@]}"; then
  echo "[ssh-test] SUCCESS"
else
  echo "[ssh-test] FAILED" >&2
  exit 1
fi

# Additional validation inside the container (tools, sudo, workspace perms, GitHub SSH)
REMOTE_CHECK_CMD=$(cat <<'REMOTE'
failed=0
echo "[ssh-remote] whoami: $(whoami)"
echo "[ssh-remote] id: $(id)"
echo "[ssh-remote] pwd: $(pwd)"
check_compilers() {
  local failed=0
  if [[ -n "${EXPECT_CLANG:-}" ]]; then
    echo "[ssh-remote] expect clang variant: ${EXPECT_CLANG}"
    if command -v "clang++-${EXPECT_CLANG}" >/dev/null 2>&1; then
      echo "[ssh-remote] found clang++-${EXPECT_CLANG}: $(command -v clang++-${EXPECT_CLANG})"
    else
      echo "[ssh-remote] MISSING clang++-${EXPECT_CLANG}"; failed=1
    fi
    if [[ "${EXPECT_CLANG}" == "p2996" ]]; then
      if [ -x /opt/clang-p2996/bin/clang++-p2996 ]; then
        echo "[ssh-remote] found clang++-p2996: /opt/clang-p2996/bin/clang++-p2996"
      else
        echo "[ssh-remote] MISSING /opt/clang-p2996/bin/clang++-p2996"; failed=1
      fi
    fi
    if [[ "${EXPECT_CLANG}" =~ ^[0-9]+$ ]]; then
      for v in 14 15 21 22; do
        if [[ "$v" != "${EXPECT_CLANG}" ]]; then
          if command -v "clang++-${v}" >/dev/null 2>&1; then
            echo "[ssh-remote] UNEXPECTED clang++-${v} present"; failed=1
          fi
        fi
      done
      for pkg in "libclang-rt-${EXPECT_CLANG}-dev" "libc++-${EXPECT_CLANG}-dev" "libc++abi-${EXPECT_CLANG}-dev"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
          echo "[ssh-remote] pkg ok: $pkg"
        else
          echo "[ssh-remote] pkg missing: $pkg"; failed=1
        fi
      done
    fi
  fi
  if [[ -n "${EXPECT_GCC:-}" ]]; then
    echo "[ssh-remote] expect gcc version: ${EXPECT_GCC}"
    if command -v "gcc-${EXPECT_GCC}" >/dev/null 2>&1; then
      echo "[ssh-remote] found gcc-${EXPECT_GCC}: $(command -v gcc-${EXPECT_GCC})"
    else
      echo "[ssh-remote] MISSING gcc-${EXPECT_GCC}"; failed=1
    fi
    if command -v "g++-${EXPECT_GCC}" >/dev/null 2>&1; then
      echo "[ssh-remote] found g++-${EXPECT_GCC}: $(command -v g++-${EXPECT_GCC})"
    else
      echo "[ssh-remote] MISSING g++-${EXPECT_GCC}"; failed=1
    fi
  fi
  return $failed
}

check_mounts() {
  local failed=0
  if mount | grep -q "/cppdev-cache"; then
    echo "[ssh-remote] cache mount present: /cppdev-cache"
    if touch /cppdev-cache/.touch_test 2>/dev/null; then
      rm -f /cppdev-cache/.touch_test
      echo "[ssh-remote] cache mount writable"
    else
      echo "[ssh-remote] cache mount NOT writable"; failed=1
    fi
  else
    echo "[ssh-remote] cache mount missing"; failed=1
  fi
  if touch "$HOME/workspace/.touch_test" 2>/dev/null; then
    rm -f "$HOME/workspace/.touch_test"
    echo "[ssh-remote] workspace writable (explicit test)"
  else
    echo "[ssh-remote] workspace NOT writable (explicit test)"; failed=1
  fi
  return $failed
}

if test -w "$HOME/workspace"; then
  echo "[ssh-remote] workspace writable: yes"
else
  echo "[ssh-remote] workspace writable: NO"; failed=1
fi
if sudo -n true >/dev/null 2>&1; then
  echo "[ssh-remote] sudo -n true: OK"
else
  echo "[ssh-remote] sudo -n true: FAILED"; failed=1
fi
for bin in ninja cmake vcpkg; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "[ssh-remote] found $bin: $(command -v "$bin")"
  else
    echo "[ssh-remote] MISSING $bin"; failed=1
  fi
done
# mrdocs may not be on PATH; check explicit location
if command -v mrdocs >/dev/null 2>&1; then
  echo "[ssh-remote] found mrdocs: $(command -v mrdocs)"
elif [[ -x /opt/mrdocs/bin/mrdocs ]]; then
  echo "[ssh-remote] found mrdocs at /opt/mrdocs/bin/mrdocs (not in PATH)"
else
  echo "[ssh-remote] MISSING mrdocs"; failed=1
fi
echo "[ssh-remote] tool versions:"
gh --version 2>/dev/null || { echo "[ssh-remote] missing gh"; failed=1; }
if aws --version 2>/dev/null; then :; elif [ -x /opt/aws-cli/v2/current/bin/aws ]; then
  /opt/aws-cli/v2/current/bin/aws --version || { echo "[ssh-remote] aws present at /opt/aws-cli but failed"; failed=1; }
else
  echo "[ssh-remote] WARNING: aws not found"; 
fi
ninja --version 2>/dev/null || { echo "[ssh-remote] missing ninja"; failed=1; }
cmake --version 2>/dev/null || { echo "[ssh-remote] missing cmake"; failed=1; }
vcpkg --version 2>/dev/null || { echo "[ssh-remote] missing vcpkg"; failed=1; }

if check_compilers; then :; else failed=1; fi
if check_mounts; then :; else failed=1; fi

# Tiny compile/link test with expected compilers and std
EXPECT_STD="${DEVCONTAINER_CXX_STD:-c++26}"
cat >/tmp/main.cpp <<'EOF'
#include <iostream>
int main() { std::cout << "OK" << std::endl; }
EOF
cat >/tmp/CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.24)
project(CompileCheck LANGUAGES CXX)
set(CMAKE_CXX_STANDARD ${EXPECT_STD#c++})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_executable(main main.cpp)
EOF
mkdir -p /tmp/build && cd /tmp/build
if [[ -n "${EXPECT_CLANG:-}" ]]; then
  env CC="clang-${EXPECT_CLANG}" CXX="clang++-${EXPECT_CLANG}" cmake -G Ninja /tmp || { echo "[ssh-remote] cmake configure failed"; failed=1; }
elif [[ -n "${EXPECT_GCC:-}" ]]; then
  env CC="gcc-${EXPECT_GCC}" CXX="g++-${EXPECT_GCC}" cmake -G Ninja /tmp || { echo "[ssh-remote] cmake configure failed"; failed=1; }
else
  cmake -G Ninja /tmp || { echo "[ssh-remote] cmake configure failed"; failed=1; }
fi
if ! ninja -v; then
  echo "[ssh-remote] build failed"; failed=1
fi
if ! ./main | grep -q OK; then
  echo "[ssh-remote] run failed"; failed=1
fi
if [[ "${EXPECT_CLANG:-}" == "p2996" ]]; then
  if [ ! -x /opt/clang-p2996/bin/clang++-p2996 ]; then
    echo "[ssh-remote] MISSING /opt/clang-p2996/bin/clang++-p2996"; failed=1
  fi
  echo "[ssh-remote] libc++ compile test for p2996"
  rm -rf /tmp/build && mkdir -p /tmp/build && cd /tmp/build
  cat >/tmp/CMakeLists.txt <<EOF
cmake_minimum_required(VERSION 3.24)
project(CompileCheckLibcxx LANGUAGES CXX)
set(CMAKE_CXX_STANDARD ${EXPECT_STD#c++})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_executable(main main.cpp)
set(CMAKE_CXX_FLAGS "-stdlib=libc++")
set(CMAKE_EXE_LINKER_FLAGS "-stdlib=libc++")
EOF
  env CC="clang-${EXPECT_CLANG}" CXX="clang++-${EXPECT_CLANG}" cmake -G Ninja /tmp || { echo "[ssh-remote] cmake libc++ configure failed"; failed=1; }
  if ! ninja -v; then echo "[ssh-remote] libc++ build failed"; failed=1; fi
  if ! ./main | grep -q OK; then echo "[ssh-remote] libc++ run failed"; failed=1; fi
fi

echo "[ssh-remote] ssh -T git@github.com (expect success message over 443)"
# Use the agent (`SSH_AUTH_SOCK`) rather than a bind-mounted private key. Only attempt ssh.github.com:443 (port 22 is blocked).
attempt_github_ssh_443() {
  local output status
  output="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -p 443 -o Hostname=ssh.github.com -T git@github.com 2>&1)"
  status=$?
  if echo "$output" | grep -qi "successfully authenticated"; then
    echo "$output"
    return 0
  fi
  echo "$output"
  return $status
}

if ssh-add -l >/dev/null 2>&1; then
  if attempt_github_ssh_443; then
    echo "[ssh-remote] ssh.github.com:443 OK"
  else
    status=$?
    echo "[ssh-remote] github.com SSH failed on 443 (exit $status)"; failed=1
  fi
else
  echo "[ssh-remote] WARNING: No SSH agent available; skipping GitHub SSH check."
fi
exit $failed
REMOTE
)

SSH_CMD_REMOTE=(ssh
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
  -o ConnectTimeout=15
  "${PROXY_OPTS[@]}"
  -p "$PORT"
  "${USER_NAME}@${TARGET_HOST}"
  EXPECT_CLANG="$EXPECT_CLANG" EXPECT_GCC="$EXPECT_GCC" DEVCONTAINER_CXX_STD="$CXX_STD" bash -lc "$REMOTE_CHECK_CMD")

echo "[ssh-test] Executing remote validation command..."
if "${SSH_CMD_REMOTE[@]}"; then
  echo "[ssh-test] Remote validation completed."
else
  echo "[ssh-test] Remote validation failed." >&2
  exit 1
fi
