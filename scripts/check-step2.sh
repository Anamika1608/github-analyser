#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_file() {
  local path="$1"
  if [[ ! -f "$ROOT_DIR/$path" ]]; then
    printf 'Missing required file: %s\n' "$path" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "$ROOT_DIR/$path" ]]; then
    printf 'Missing required directory: %s\n' "$path" >&2
    exit 1
  fi
}

printf 'Checking Step 2 ingestion outputs in %s\n' "$ROOT_DIR"

require_file "README.md"
require_file ".env.example"
require_file "data/raw/repos.json"
require_file "data/raw/events.json"
require_file "data/raw/manifest.json"
require_dir "data/raw/commits"

if ! find "$ROOT_DIR/data/raw/commits" -type f -name '*.json' | grep -q .; then
  printf 'Expected at least one commit snapshot in data/raw/commits\n' >&2
  exit 1
fi

printf 'Step 2 ingestion check passed.\n'
