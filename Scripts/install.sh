#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/build/DerivedData/Build/Products/Debug/FinderPasteFix.app"
INSTALL_DIR="${FINDERPASTEFIX_INSTALL_DIR:-$HOME/Applications}"
DEST_APP="$INSTALL_DIR/FinderPasteFix.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

"$ROOT_DIR/Scripts/build.sh"

pkill -x FinderPasteFix 2>/dev/null || true
mkdir -p "$INSTALL_DIR"
rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"
xattr -c "$DEST_APP" 2>/dev/null || true
"$LSREGISTER" -f -R -trusted "$DEST_APP" 2>/dev/null || true

echo "Installed to: $DEST_APP"
codesign -dv --verbose=2 "$DEST_APP" 2>&1 | sed -n '1,80p'
codesign --verify --deep --strict --verbose=2 "$DEST_APP"
