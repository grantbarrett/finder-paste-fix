#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-local.finderpastefix}"
INSTALLED_APP="${FINDERPASTEFIX_INSTALLED_APP:-$HOME/Applications/FinderPasteFix.app}"
USER_TCC_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
SYSTEM_TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

print_tcc_rows() {
  local label="$1"
  local database="$2"

  echo
  echo "$label"
  if [[ ! -r "$database" ]]; then
    echo "  unreadable: $database"
    return
  fi

  sqlite3 "$database" "
    select
      service,
      client,
      auth_value,
      auth_reason,
      datetime(last_modified, 'unixepoch', 'localtime')
    from access
    where client = '$BUNDLE_ID'
    order by service;
  " | sed 's/^/  /'
}

echo "Bundle ID: $BUNDLE_ID"
echo "Installed app: $INSTALLED_APP"

echo
echo "Running processes"
ps -axo pid,comm,args | rg "FinderPasteFix|$INSTALLED_APP|DerivedData" || true

if [[ -d "$INSTALLED_APP" ]]; then
  echo
  echo "Installed app signature"
  codesign -dvv "$INSTALLED_APP" 2>&1 | sed -n '1,24p' | sed 's/^/  /'
  codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP" 2>&1 | sed 's/^/  /'
fi

print_tcc_rows "User TCC rows" "$USER_TCC_DB"
print_tcc_rows "System TCC rows" "$SYSTEM_TCC_DB"
