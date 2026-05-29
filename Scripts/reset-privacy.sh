#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-local.finderpastefix}"

pkill -x FinderPasteFix 2>/dev/null || true

for SERVICE in Accessibility ListenEvent PostEvent; do
  tccutil reset "$SERVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
done

tccutil reset All "$BUNDLE_ID" >/dev/null 2>&1 || true

cat <<EOF
Reset macOS privacy permissions for $BUNDLE_ID.

Next:
1. Run ./Scripts/install.sh
2. Run ./Scripts/restart.sh
3. Use the menu bar item to grant Accessibility and Input Monitoring.
4. Quit and run ./Scripts/restart.sh again if either permission still reads Needed.
EOF
