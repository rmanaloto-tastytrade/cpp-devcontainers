#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Render Mermaid diagrams to SVG/PNG.

Usage: scripts/render_diagrams.sh [--input <dir>] [--output <dir>] [--formats svg,png]

Defaults:
  --input    docs/Diagrams
  --output   docs/Diagrams/rendered
  --formats  svg,png
Environment:
  MERMAID_CMD   Override mermaid CLI command (default: mmdc, fallback: npx @mermaid-js/mermaid-cli@10.9.1)
USAGE
}

INPUT_DIR="docs/Diagrams"
OUTPUT_DIR="docs/Diagrams/rendered"
FORMATS="svg,png"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT_DIR="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --formats) FORMATS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory not found: $INPUT_DIR" >&2
  exit 1
fi

MERMAID_CMD="${MERMAID_CMD:-}"
if [[ -z "$MERMAID_CMD" ]]; then
  if command -v mmdc >/dev/null 2>&1; then
    MERMAID_CMD="mmdc"
  elif command -v npx >/dev/null 2>&1; then
    MERMAID_CMD="npx -y @mermaid-js/mermaid-cli@10.9.1"
  else
    echo "Mermaid CLI not found. Install @mermaid-js/mermaid-cli or set MERMAID_CMD." >&2
    exit 1
  fi
fi

IFS=',' read -r -a FORMAT_LIST <<< "$FORMATS"
mkdir -p "$OUTPUT_DIR"

mapfile -t FILES < <(find "$INPUT_DIR" -type f -name "*.mmd" | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No .mmd files found under $INPUT_DIR" >&2
  exit 1
fi

for file in "${FILES[@]}"; do
  rel="${file#"$INPUT_DIR"/}"
  stem="${rel%.mmd}"
  for fmt in "${FORMAT_LIST[@]}"; do
    out_dir="$(dirname "$OUTPUT_DIR/$rel")"
    mkdir -p "$out_dir"
    out_file="$OUTPUT_DIR/${stem}.${fmt}"
    echo "Rendering $file -> $out_file"
    # shellcheck disable=SC2086
    $MERMAID_CMD -i "$file" -o "$out_file" -w 1200
  done
done
