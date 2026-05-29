#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED_APP="${FINDERPASTEFIX_INSTALLED_APP:-/Applications/FinderPasteFix.app}"

if [[ ! -d "$INSTALLED_APP" ]]; then
  echo "Installed app not found: $INSTALLED_APP" >&2
  echo "Run ./Scripts/install.sh first so macOS privacy permissions attach to a stable app path." >&2
  exit 1
fi

open "$INSTALLED_APP"
