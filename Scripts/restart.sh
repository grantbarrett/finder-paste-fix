#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED_APP="${FINDERPASTEFIX_INSTALLED_APP:-/Applications/FinderPasteFix.app}"

pkill -x FinderPasteFix 2>/dev/null || true

if [[ ! -d "$INSTALLED_APP" ]]; then
  echo "Installed app not found; installing first."
  "$ROOT_DIR/Scripts/install.sh"
fi

"$ROOT_DIR/Scripts/run.sh"
