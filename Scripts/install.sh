#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/build/DerivedData/Build/Products/Debug/FinderPasteFix.app"
INSTALL_DIR="${FINDERPASTEFIX_INSTALL_DIR:-/Applications}"
DEST_APP="${FINDERPASTEFIX_INSTALLED_APP:-$INSTALL_DIR/FinderPasteFix.app}"
DEST_DIR="$(dirname "$DEST_APP")"
LEGACY_APP="$HOME/Applications/FinderPasteFix.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

"$ROOT_DIR/Scripts/build.sh"

pkill -x FinderPasteFix 2>/dev/null || true
mkdir -p "$DEST_DIR"

if [[ ! -w "$DEST_DIR" ]]; then
  cat >&2 <<EOF
Cannot write to $DEST_DIR.

Install from an admin account, or use a development override:
  FINDERPASTEFIX_INSTALL_DIR="$HOME/Applications" ./Scripts/install.sh
EOF
  exit 1
fi

rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"
xattr -c "$DEST_APP" 2>/dev/null || true
"$LSREGISTER" -f -R -trusted "$DEST_APP" 2>/dev/null || true

if [[ "$DEST_APP" != "$LEGACY_APP" && -d "$LEGACY_APP" ]]; then
  echo "Note: legacy per-user install still exists at: $LEGACY_APP"
  echo "Remove it if macOS privacy settings show more than one Finder Paste Fix entry."
fi

echo "Installed to: $DEST_APP"
codesign -dv --verbose=2 "$DEST_APP" 2>&1 | sed -n '1,80p'
codesign --verify --deep --strict --verbose=2 "$DEST_APP"
