# AI Agent CLI Usage (Non-Interactive)

Purpose: run Codex, Claude, and Gemini CLIs in non-interactive mode to review project docs/plans with maximum context and reproducible filenames.

## Timestamp format
- Use a uniform timestamp for output filenames: `$(date +%Y%m%d%H%M%S.%N)` (nanoseconds are zero-padded).

## Prompt shaping (general)
- Keep prompts explicit: ask for issues/bugs/gaps/optimizations, not summaries only.
- Include the full document text inline so the model has maximum context (use `cat` in the heredoc).
- Request concise, actionable bullets and explicit “risks/unknowns”.

## Codex CLI (non-interactive)
- Command: `codex exec` (non-interactive), pass prompt via stdin/heredoc.
- Example (review self-hosted plan):
  ```bash
  ts=$(date +%Y%m%d%H%M%S.%N)
  codex exec --sandbox read-only --ask-for-approval never --output-last-message ./docs/ai_reviews/codex.self_hosted_devcontainer_gha_plan_review.$ts.md <<'EOF'
  Review the self-hosted devcontainer GHA plan below. Find bugs/gaps/risks/optimizations; keep bullets concise and actionable.
  ---PLAN---
  {{plan_contents}}
  EOF
  ```
  Replace `{{plan_contents}}` with `$(cat docs/self_hosted_devcontainer_gha_plan.md)` or similar.

## Claude CLI (non-interactive)
- Command: `claude -p "<prompt>" --print` (non-interactive). Use `--output-format text|json|stream-json` as needed.
- Example:
  ```bash
  ts=$(date +%Y%m%d%H%M%S.%N)
  prompt="$(cat <<'EOF'
  Review the self-hosted devcontainer GHA plan below. Find bugs/gaps/risks/optimizations; keep bullets concise and actionable.
  ---PLAN---
  {{plan_contents}}
  EOF
  )"
  claude -p "$prompt" --print --output-format text > ./docs/ai_reviews/claude.self_hosted_devcontainer_gha_plan_review.$ts.md
  ```

## Gemini CLI (non-interactive)
- The Gemini CLI exposes a `-p/--prompt` flag for non-interactive mode (positional prompt is also supported). Use `--output-format text|json|stream-json` to control output.
- Example:
  ```bash
  ts=$(date +%Y%m%d%H%M%S.%N)
  prompt="$(cat <<'EOF'
  Review the self-hosted devcontainer GHA plan below. Find bugs/gaps/risks/optimizations; keep bullets concise and actionable.
  ---PLAN---
  {{plan_contents}}
  EOF
  )"
  gemini --prompt "$prompt" --output-format text > ./docs/ai_reviews/gemini.self_hosted_devcontainer_gha_plan_review.$ts.md
  ```

## Cursor Agent CLI (non-interactive)
- Command: `cursor-agent --print` (non-interactive). Supports `--workspace` to set cwd.
- Example:
  ```bash
  ts=$(date +%Y%m%d%H%M%S.%N)
  prompt="$(cat <<'EOF'
  Review the self-hosted devcontainer GHA plan below. Find bugs/gaps/risks/optimizations; keep bullets concise and actionable.
  ---PLAN---
  {{plan_contents}}
  EOF
  )"
  cursor-agent --print --workspace . "$prompt" > ./docs/ai_reviews/cursor.self_hosted_devcontainer_gha_plan_review.$ts.md
  ```

## Copilot CLI (non-interactive)
- Command: `copilot -p "<prompt>" --allow-all-tools` (non-interactive). Use `--model` if needed.
- Example:
  ```bash
  ts=$(date +%Y%m%d%H%M%S.%N)
  prompt="$(cat <<'EOF'
  Review the self-hosted devcontainer GHA plan below. Find bugs/gaps/risks/optimizations; keep bullets concise and actionable.
  ---PLAN---
  {{plan_contents}}
  EOF
  )"
  copilot -p "$prompt" --allow-all-tools > ./docs/ai_reviews/copilot.self_hosted_devcontainer_gha_plan_review.$ts.md
  ```

## Docker AI (Ask Gordon) CLI (non-interactive)
- Command: `docker ai "<prompt>" --working-dir .` (prints response to stdout; use `> file` to capture).
- Example:
  ```bash
  ts=$(date +%Y%m%d%H%M%S.%N)
  prompt="$(cat <<'EOF'
  Review the self-hosted devcontainer GHA plan below. Find bugs/gaps/risks/optimizations; keep bullets concise and actionable.
  ---PLAN---
  {{plan_contents}}
  EOF
  )"
  docker ai "$prompt" --working-dir . > ./docs/ai_reviews/dockerai.self_hosted_devcontainer_gha_plan_review.$ts.md
  ```

## Notes
- Ensure API keys/config for each CLI are already set up (login/credentials not covered here).
- Keep CLIs in read-only/safe modes for review tasks; no tool execution is needed for doc analysis.
