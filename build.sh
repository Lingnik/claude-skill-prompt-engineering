#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SCRIPT_DIR}/../prompt-engineering-models.skill"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--output <path>] [--help]

Build the prompt-engineering-models.skill zip archive.

Options:
  --output <path>   Output file path (default: ../prompt-engineering-models.skill)
  --help            Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

cd "$SCRIPT_DIR"

echo "Building skill archive..."
zip -r "$OUTPUT" SKILL.md references/ -x "*.DS_Store"
echo "Created: $OUTPUT"
