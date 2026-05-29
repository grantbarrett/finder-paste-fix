#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
LOCAL_IDENTITY_NAME="FinderPasteFix Local Code Signing"

cd "$ROOT_DIR"

code_sign_identity="${FINDERPASTEFIX_CODE_SIGN_IDENTITY:-}"

if [[ -z "$code_sign_identity" ]]; then
  code_sign_identity="$(
    security find-identity -v -p codesigning 2>/dev/null |
      awk -F '"' -v name="$LOCAL_IDENTITY_NAME" '$0 ~ name { print $2; exit }'
  )"
fi

if [[ -z "$code_sign_identity" ]]; then
  code_sign_identity="$(
    security find-identity -v -p codesigning 2>/dev/null |
      awk -F '"' '/Apple Development/ { print $2; exit }'
  )"
fi

signing_args=()
if [[ -n "$code_sign_identity" ]]; then
  echo "Signing with: $code_sign_identity"
  signing_args=("CODE_SIGN_IDENTITY=$code_sign_identity" "CODE_SIGN_STYLE=Manual")
else
  echo "No code signing identity found; falling back to ad-hoc signing."
  signing_args=("CODE_SIGN_IDENTITY=-" "CODE_SIGN_STYLE=Manual")
fi

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  -project FinderPasteFix.xcodeproj \
  -scheme FinderPasteFix \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  ENABLE_DEBUG_DYLIB=NO \
  "${signing_args[@]}" \
  build
