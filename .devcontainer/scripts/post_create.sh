#!/usr/bin/env bash
set -euo pipefail

sudo chown -R slotmap:slotmap /opt/vcpkg
sudo chown -R slotmap:slotmap /workspaces

cmake --preset clang-debug
