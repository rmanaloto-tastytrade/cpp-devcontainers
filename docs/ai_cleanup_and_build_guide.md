# AI Agent Guide: Cleanup & Iterative Build Verification

This guide enables AI agents to safely reset the environment and comprehensively validate all devcontainer permutations for the `SergeyMakeev/SlotMap` project.

## 1. Safe Cleanup Procedure

**Objective:** Remove *only* Docker containers, images, and volumes related to this specific project, ensuring no collateral damage to other workloads on the host.

### Targeting Strategy

* **Containers:** Filter by label `devcontainer.local_folder` or ancestor images.
* **Images:** Filter by repositories `cpp-cpp-devcontainer` and `cpp-cpp-dev-base`.
* **Volumes:** Targeted removal of the named volume `cppdev-cache`.

### Cleanup Commands (Host Execution)

Execute these commands on the **remote host** (e.g., `c090s4`) or local machine depending on context.

```bash
# 1. Stop and remove all running containers for this project
#    (Filters by the project's specific image tags)
docker ps -a --filter "ancestor=cpp-cpp-devcontainer,cpp-cpp-dev-base" --format "{{.ID}}" | xargs -r docker rm -f

# 2. Remove devcontainer and base images
#    (Using wildcards to catch all tags like :gcc14-clang21, :local, etc.)
docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "^(cpp-cpp-devcontainer|cpp-cpp-dev-base)" | xargs -r docker rmi -f

# 3. Remove the project-specific cache volume
#    (WARNING: Destroys ccache/vcpkg cache. Only do this for a full hard reset.)
docker volume rm cppdev-cache || echo "Volume cppdev-cache not found or already removed."

# 4. Cleanup dangling build metadata (optional but recommended)
rm -rf ~/dev/devcontainers/build_meta/*
```

---

## 2. Iterative Build & Verification Permutations

**Objective:** Sequentially build and validate every configured toolchain permutation to ensure the matrix is stable.

### Configuration Matrix (c090s4)

The following environment files in `config/env/` define the permutations:

1. `devcontainer.c090s4.gcc14-clang21.env`
2. `devcontainer.c090s4.gcc14-clang22.env`
3. `devcontainer.c090s4.gcc14-clangp2996.env`
4. `devcontainer.c090s4.gcc15-clang21.env`
5. `devcontainer.c090s4.gcc15-clang22.env`
6. `devcontainer.c090s4.gcc15-clangp2996.env`

### Validation Checklist

For each permutation, the agent must verify:

* [ ] **Base Image:** `docker buildx bake base` succeeds.
* [ ] **Package Check:** Critical packages (`clang++`, `g++`, `cmake`, `ninja`) function inside the container.
* [ ] **Devcontainer Up:** Container starts without errors (exit code 0).
* [ ] **SSH Access:** `ssh` into the container on the mapped port works.

### Automated Iteration Script

Use this script to perform the loop. Note: Adjust `HOST` if not running against `c090s4`.

```bash
#!/bin/bash
set -euo pipefail

# Define permutations
CONFIGS=(
  "gcc14-clang21"
  "gcc14-clang22"
  "gcc14-clangp2996"
  "gcc15-clang21"
  "gcc15-clang22"
  "gcc15-clangp2996"
)

CLIENT_LOG_DIR="logs/matrix_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$CLIENT_LOG_DIR"

echo "Starting matrix build verification..."

for conf in "${CONFIGS[@]}"; do
  ENV_FILE="config/env/devcontainer.c090s4.${conf}.env"
  LOG_FILE="${CLIENT_LOG_DIR}/${conf}.log"
  
  echo "---------------------------------------------------"
  echo "Processing: $conf"
  echo "Config: $ENV_FILE"
  echo "Log: $LOG_FILE"
  
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: Config file $ENV_FILE missing!" | tee -a "$LOG_FILE"
    continue
  fi

  # 1. Clean previous container for this slot (if strictly sequential)
  #    Note: deploy_remote_devcontainer.sh handles container teardown, 
  #    but we force it here to be sure.
  
  # 2. Deploy & Build
  #    (This runs rsync, builds base+dev images, and starts the container)
  if (set -a && source "$ENV_FILE" && set +a && ./scripts/deploy_remote_devcontainer.sh > "$LOG_FILE" 2>&1); then
    echo "✅ [PASS] Build & Deploy: $conf"
  else
    echo "❌ [FAIL] Build & Deploy: $conf (Check $LOG_FILE)"
    continue # Skip verification if deploy failed
  fi

  # 3. Extract Validation Info from Env
  #    (Re-source to get variables for verification)
  (
    set -a && source "$ENV_FILE" && set +a
    REMOTE_HOST="${DEVCONTAINER_REMOTE_HOST}"
    SSH_PORT="${DEVCONTAINER_SSH_PORT:-9222}"
    
    # 4. Verify SSH Access
    echo "   Verifying SSH access to ${REMOTE_HOST}:${SSH_PORT}..."
    if ./scripts/test_devcontainer_ssh.sh --host "$REMOTE_HOST" --port "$SSH_PORT" --auto-accept; then
       echo "✅ [PASS] SSH Access: $conf"
    else
       echo "❌ [FAIL] SSH Access: $conf"
    fi
  )
done

echo "Matrix verification complete. Summary in $CLIENT_LOG_DIR"
```

### Verification Failure Troubleshooting

* **SSH Failures:** unexpected `known_hosts` collisions (use `ssh-keygen -R [host]:port`), or missing public keys in `~/.ssh`.
* **Build Failures:** Check remote logs. If `ty` installs fail, confirm the fix (removal) was deployed. If `mkdir` permission denied, confirm the `chown` fix runs.
